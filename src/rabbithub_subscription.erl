-module(rabbithub_subscription).

-export([start_subscriptions/0]).
-export([create/7, delete/1, deactivate/1]).
-export([start_link/1]).
-export([register_subscription_pid/3, erase_subscription_pid/1, delete_local_consumer/1]).

%% Internal export
-export([expire/1]).
-export([system_time/0]).

-include("rabbithub.hrl").
-include_lib("rabbit-common/include/rabbit.hrl").
-include_lib("rabbit-common/include/rabbit_framing.hrl").

%% Should be exported by timer module, but isn't
%this cannot be  used until on erlang 18+
system_time() -> 
    erlang:system_time(1000000).

%system_time() ->
%    {MegaSec, Sec, MicroSec} = now(),
%    1000000 * (MegaSec * 1000000 + Sec) + MicroSec.

start_subscriptions() ->
    rabbit_log:info("Starting subscriptions...~n"),
    %% If it's the first time the plugin is used or its a new Mnesia DB, there's a
    %% chance the tables may not exist or are not available when we go looking for 
    %% them, so just to be sure we try creating them here. If they already exist 
    %% then no problem. Room for improvement here!
    rabbithub:setup_schema(),

    {atomic, Leases} =
        mnesia:transaction(fun () ->
                                   mnesia:foldl(fun (Lease, Acc) -> [Lease | Acc] end,
                                                [],
                                                rabbithub_lease)
                           end),
    lists:foreach(fun start/1, Leases).

create(Subscription, LeaseSeconds, HAMode, MaxTps, Status, OutboundAuth, ContactRec) ->
    rabbithub_consumer:erase_subscription_err(Subscription),
    RequestedExpiryTime = system_time() + LeaseSeconds * 1000000,    
    Lease = #rabbithub_lease{subscription = Subscription,
                             lease_expiry_time_microsec = RequestedExpiryTime,
                             lease_seconds = LeaseSeconds,
                             ha_mode = HAMode,
                             status = Status,
                             max_tps = MaxTps},
                             
                                     
    {atomic, Result} = mnesia:sync_transaction(
        fun () ->            
            case mnesia:read(rabbithub_lease, Subscription) of
                [ExistingRecord] ->                
                    UpdatedRecord = ExistingRecord#rabbithub_lease{lease_expiry_time_microsec = RequestedExpiryTime, 
                                        lease_seconds = LeaseSeconds, ha_mode = HAMode, status = Status, max_tps = MaxTps},
                    {atomic, ok} = mnesia:transaction(fun () ->                         
                        ok = mnesia:write(UpdatedRecord) end),
                    UpdatedRecord;                        
                [] -> 
                    {atomic, ok} = mnesia:transaction(fun () -> ok = mnesia:write(Lease) end),
                    Lease                  
            end
        end),
    {atomic, _ResultOA} = mnesia:sync_transaction(
        fun() ->
            case OutboundAuth of
                [] -> check_and_delete_outbound_auth(Subscription);
                undefined -> check_and_delete_outbound_auth(Subscription);                                    
                OA -> %%write record
                    {atomic, ok} = mnesia:transaction(fun () -> mnesia:write(OA) end),
                    ok
            end
        end),
    {atomic, _ResultC} = mnesia:sync_transaction(
        fun() ->
            case ContactRec of
                [] -> check_and_delete_contact(Subscription, ContactRec);
                undefined -> check_and_delete_contact(Subscription, ContactRec);                                    
                C -> %%write record                    
                    SubscriberContactInfo = #rabbithub_subscriber_contact_info{subscription = Subscription, contact_info = C},
                    {atomic, ok} = mnesia:transaction(fun () -> mnesia:write(SubscriberContactInfo) end),
                    ok
            end
        end),
    
    start(Result).

check_and_delete_outbound_auth(Subscription) ->    
    mnesia:transaction(fun () ->
        case mnesia:read(rabbithub_outbound_auth, Subscription) of
            [] -> do_nothing;
            [_ExistingRecord] ->  
                mnesia:delete({rabbithub_outbound_auth, Subscription})
        end
    end).

check_and_delete_contact(Subscription, _Contact) ->    
    mnesia:transaction(fun () ->
        case mnesia:read(rabbithub_subscriber_contact_info, Subscription) of
            [] -> do_nothing;
            [_ExistingRecord2] ->  
                mnesia:delete({rabbithub_subscriber_contact_info, Subscription})
        end
    end).

    
%%GF changing unsubscription to set status to inactive instead of deleting from table
deactivate(Subscription) ->
    Consumer = #rabbithub_consumer{subscription = Subscription, node = node()},
    rabbit_log:info("RabbitHub deactivate subscription~n~p~n", [Subscription]),
    
    case update_lease_status(Subscription, inactive) of
        {atomic, ok} ->        
            {atomic, SubPids} =        
                mnesia:transaction(
                  fun () ->
                          SubPids = mnesia:read({rabbithub_subscription_pid, Consumer}),
                          ok = mnesia:delete({rabbithub_subscription_pid, Consumer}),
                          SubPids
                  end),
            lists:foreach(fun (#rabbithub_subscription_pid{pid = Pid,
                                                           expiry_timer = TRef}) ->
                                  {ok, cancel} = timer:cancel(TRef),
                                  gen_server:cast(Pid, shutdown)
                          end, SubPids),
            ok;
        {aborted, {{badmatch, _},_}} -> {error, not_found};
        {aborted, Reason} -> {error, Reason}
    end.


update_lease_status(Subscription, Status) ->
    LeaseUpdateFun = fun() ->
        [L] = mnesia:read({rabbithub_lease, Subscription}),        
        mnesia:write(L#rabbithub_lease{status = Status})
    end,

    mnesia:transaction(LeaseUpdateFun).
    
%update_lease_pseudo_queue(Subscription, Q) ->
%    LeaseUpdateFun = fun() ->
%        [L] = mnesia:read({rabbithub_lease, Subscription}),        
%        mnesia:write(L#rabbithub_lease{pseudo_queue = Q})
%    end,
%
%    mnesia:transaction(LeaseUpdateFun).

delete(Subscription) ->
    Consumer = #rabbithub_consumer{subscription = Subscription, node = node()},
    rabbit_log:info("RabbitHub deleting subscription~n~p~n", [Consumer]),
    R3 = mnesia:transaction(fun () -> mnesia:read({rabbithub_lease, Subscription}) end),
    R4 = case R3 of
        {atomic, []} ->
            {error, not_found};       
        {atomic, [Lease]} ->
            _R1 = mnesia:transaction(fun () -> mnesia:delete({rabbithub_lease, Subscription}) end),
            check_and_delete_outbound_auth(Subscription),            
            delete_local_consumer(Subscription, Lease),
            Lease;
        {aborted, Reason} -> 
            {error, Reason}
    end,
    case R4 of
        {error, Reason2} -> {error, Reason2};
        L2 ->            
            Resource2 = (L2#rabbithub_lease.subscription)#rabbithub_subscription.resource,                  
            ResourceType = Resource2#resource.kind,                  
            case ResourceType of
                queue -> ok;
                exchange ->
                    case application:get_env(rabbithub, use_internal_queue_for_pseudo_queue) of
                        {ok, false} ->
                            %% if resource type = exchange and env = false, and pseudo queue has been created, delete psuedo_queue            
                            PseudoQueue = L2#rabbithub_lease.pseudo_queue,                            
                            case PseudoQueue of
                                undefined ->
                                    ok;
                                PQ ->
                                    QueueName = PQ#amqqueue.name,        
                                    case rabbit_amqqueue:lookup(QueueName) of
                                        {error, not_found} ->
                                            rabbit_log:info("RabbitHub error deleting Pseudo Queue ~p Reason not found.~nFor Subscription ~p~n", 
                                                [QueueName,Subscription]);
                                        {ok, Q} ->
                                            {ok, PurgedMessageCount} = rabbit_amqqueue:delete(Q, false, false),
                                            rabbit_log:info("RabbitHub deleted pseudo queue ~p with ~p messages purged~n for Subscription ~p~n", 
                                                [QueueName, PurgedMessageCount, Subscription])
                                    end
                            end,
                            ok;
                        %% If usings standard pseudo queue then do nothing, queue aleady deleted.    
                        _ -> ok
                end
            end
    end.
                 

delete_local_consumer(Subscription) ->
    {atomic, [Lease]} = mnesia:transaction(fun () -> mnesia:read({rabbithub_lease, Subscription}) end), 
    delete_local_consumer(Subscription, Lease).
    
delete_local_consumer(Subscription, _Lease) ->
    Consumer = #rabbithub_consumer{subscription = Subscription, node = node()},
    Consumers =        
         mnesia:transaction(
              fun () ->
                      SubPids1 = mnesia:read({rabbithub_subscription_pid, Consumer}),
                      ok = mnesia:delete({rabbithub_subscription_pid, Consumer}),
                      SubPids1
              end),          
    {atomic, SubPids2} = Consumers,
    %% cancel all local consumers should only be one
    lists:foreach(fun (#rabbithub_subscription_pid{pid = Pid,
                                                   expiry_timer = TRef}) ->
                          {ok, cancel} = timer:cancel(TRef),
                          gen_server:cast(Pid, shutdown)
                  end, SubPids2),
    ok.                  
     



expire(Subscription) ->
    rabbit_log:info("RabbitHub expiring subscription~n~p~n", [Subscription]),
    deactivate(Subscription).

start_link(Lease =
           #rabbithub_lease{subscription =
                            #rabbithub_subscription{resource =
                                                    #resource{kind = ResourceTypeAtom}}}) ->
    case ResourceTypeAtom of
        exchange ->
            case application:get_env(rabbithub, use_internal_queue_for_pseudo_queue) of
                {ok, false} ->                    
                    case create_and_bind_pseudo_queue(Lease) of
                        {stop, not_found} -> {stop, not_found};
                        Resource ->                             
                            gen_server:start_link(rabbithub_consumer, [Lease, Resource], [])
                    end; 
                _ ->
                    gen_server:start_link(rabbithub_pseudo_queue, [Lease], [])
            end;
        queue ->
            gen_server:start_link(rabbithub_consumer, [Lease], [])
    end.

create_and_bind_pseudo_queue(Lease = #rabbithub_lease{subscription =
                             #rabbithub_subscription{resource =
                              #resource{virtual_host = VHost, kind = _ResourceTypeAtom, name = ExchangeNameBin}, topic = Topic}}) ->
    %%check for existing record and pseudo queue
    {atomic, ResultPQ} =
        mnesia:transaction(
          fun () ->
              Subscription = Lease#rabbithub_lease.subscription,
              case mnesia:read(rabbithub_lease, Subscription) of
                  [ExistingRecord] ->
                      ExistingPseudoQueue = ExistingRecord#rabbithub_lease.pseudo_queue,
                      case ExistingPseudoQueue of
                          undefined -> create_new_queue;
                          PQ -> PQ
                      end                      
              end
    end),
    case ResultPQ of 
        create_new_queue ->
            %% generate queue_name                          
            QueueNameBin = rabbit_guid:binary(rabbit_guid:gen(), "amq.http.pseudoqueue"),
            QueueResource = #resource{virtual_host = VHost, kind = queue, name = QueueNameBin},
            %% create queue if it does not already exist
            Q = case rabbit_amqqueue:lookup(QueueResource) of
                {ok, _} ->
                    already_exists;
                {error, not_found} ->
                    {new, Qrec} = rabbit_amqqueue:declare(QueueResource, true, false, [], none),
                    Qrec
            end,
            %% bind queue to exchange
            Resource = #resource{virtual_host = VHost, kind = exchange, name = ExchangeNameBin},
            case rabbit_binding:add(#binding{source     = Resource,
                                            destination = QueueResource,
                                            key         = list_to_binary(Topic),
                                            args        = []}) of        
                ok ->
                    {atomic, _Result} =
                        mnesia:sync_transaction(
                          fun () ->
                              Subscription = Lease#rabbithub_lease.subscription,
                              case mnesia:read(rabbithub_lease, Subscription) of
                                  [ExistingRecord] ->
                                      ok = mnesia:write(ExistingRecord#rabbithub_lease{pseudo_queue = Q})
                              end
                    end),
                    QueueResource;
                {error, exchange_not_found} ->
                    {stop, not_found};
                _Err ->
                    {stop, not_found}
                
            end;
        ExistingPQResource ->  
            ExistingPQResource#amqqueue.name                                     
    end.
             
       


start(Lease) ->
    case Lease#rabbithub_lease.status of
        active ->
            case supervisor:start_child(rabbithub_subscription_sup, [Lease]) of
                {ok, _Pid} ->
                    ok;
                {error, normal} ->
                    %% duplicate processes return normal, so as to not provoke the error logger.
                    ok;
                {error, Reason} ->
                    {error, Reason}
            end;
        _Other ->
            ok
    end.

register_subscription_pid(Lease, Pid, ProcessModule) ->
    Result = register_subscription_pid1(Lease, Pid),
    rabbit_log:info("RabbitHub register subscription (startup); ~p~n~p~n~p~n", [Result, ProcessModule, Lease]),
    Result.

register_subscription_pid1(#rabbithub_lease{subscription = Subscription,
                                            lease_expiry_time_microsec = ExpiryTimeMicro},
                           Pid) ->                          
    NowMicro = system_time(),
    Node = node(),    
    Consumer = #rabbithub_consumer{subscription = Subscription, node = node()}, 
    case NowMicro > ExpiryTimeMicro of
        true ->
            %% Expired.
            ok = deactivate(Subscription),
            expired;
        false ->
            %% Not *yet* expired. Always start a timer, since even if
            %% it's a duplicate we want to cancel the existing timer
            %% and create a new timer to fire at the new time.
            {ok, TRef} = timer:apply_after((ExpiryTimeMicro - NowMicro) div 1000,
                                           ?MODULE, expire, [Subscription]),                                           
            NewPidRecord = #rabbithub_subscription_pid{consumer = Consumer,
                                                       pid = Pid,
                                                       expiry_timer = TRef},
            {atomic, Result} =
                mnesia:transaction(
                  fun () ->
                          case mnesia:read(rabbithub_subscription_pid, Consumer) of
                              [] ->
                                  ok = mnesia:write(NewPidRecord);
                              [ExistingRecord =
                                 #rabbithub_subscription_pid{pid = ExistingPid,
                                                             expiry_timer = OldTRef}] ->
                                  %% check if the ExistingPid is from the local node to avoid illegal call to is_process_alive
                                  PidNode = node(ExistingPid),
                                  case Node == PidNode of
                                      true ->
                                          case is_process_alive(ExistingPid) of
                                              true ->
                                                  {ok, cancel} = timer:cancel(OldTRef),
                                                  R1 = ExistingRecord#rabbithub_subscription_pid{
                                                         expiry_timer = TRef},
                                                  ok = mnesia:write(R1),
                                                  duplicate;
                                              false ->
                                                  ok = mnesia:write(NewPidRecord)
                                          end;
                                      false ->
                                          rabbit_log:info("Rabbithub subscription ~p running on remote node: ~p.  Ignore as duplicate~n", [Subscription, PidNode]),
                                          duplicate
                                  end
                          end
                  end),
            Result
    end.

erase_subscription_pid(Subscription) ->
    Consumer = #rabbithub_consumer{subscription = Subscription, node = node()}, 
    {atomic, ok} =
        mnesia:transaction(fun () -> mnesia:delete({rabbithub_subscription_pid, Consumer}) end),
    ok.
