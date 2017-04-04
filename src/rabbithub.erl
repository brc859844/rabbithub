-module(rabbithub).
-behaviour(application).

-export([start/2, stop/1]).
-export([setup_schema/0]).
-export([instance_key/0, sign_term/1, verify_term/1]).
-export([b64enc/1, b64dec/1]).
-export([canonical_scheme/0, canonical_host/0, canonical_basepath/0]).
-export([default_username/0]).
-export([r/3,r/2]).
-export([respond_xml/5]).
-export([deliver_via_post/4, error_and_unsub/2, error_and_delete_sub/2]).

-export([init/1]).

%% Start subscriptions via a bootstep only once routing is ready. Schema might
%% already be set up, which is fine.
-rabbit_boot_step({?MODULE,
                   [{description, "RabbitHub"},
                    {mfa, {rabbithub, setup_schema, []}},
                    {mfa, {rabbit_sup, start_child, [rabbithub_sup]}},
                    {mfa, {rabbithub_subscription, start_subscriptions, []}},
                    {requires, routing_ready}]}).

-include_lib("xmerl/include/xmerl.hrl").
-include_lib("rabbit-common/include/rabbit.hrl").
-include_lib("rabbit-common/include/rabbit_framing.hrl").
-include("rabbithub.hrl").


start(_Type, _StartArgs) ->
    hub_init(),
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) -> {ok, {{one_for_one, 1, 5}, []}}.

hub_init() ->
    setup_schema(),
    ssl:start(),

    %% Sort out HTTP client options
    HttpOpts =  get_env(http_client_options, []), 
    ok = httpc:set_options(HttpOpts),
    {ok, Opts} = httpc:get_options(all),
%% GF added enviornment parameters and application version
    EnvPars = application:get_all_env(),
    {ok, AppVsn} = application:get_key(vsn),
    rabbithub_web:start(),
    rabbit_log:info("RabbitHub started~n"),
    rabbit_log:info("RabbitHub Version:~p~n", [AppVsn]),
    rabbit_log:info("RabbitHub HTTP client options:~n~p~n", [Opts]),
    rabbit_log:info("RabbitHub Environment parameters:~n~p~n", [EnvPars]).


stop(_State) ->
    ok.

setup_schema() ->
    %% Get all DB Nodes in cluster for creating distributed mnesia tables
    DBNodes = mnesia:system_info(db_nodes),
    %% Create disc copy of rabbithub_lease across all ndoes
    ok = create_table(rabbithub_lease,
                     [{attributes, record_info(fields, rabbithub_lease)},
                      {disc_copies, DBNodes}]),
    ok = create_table(rabbithub_outbound_auth,
                     [{attributes, record_info(fields, rabbithub_outbound_auth)},
                      {disc_copies, DBNodes}]),
    ok = create_table(rabbithub_subscriber_contact_info,
                     [{attributes, record_info(fields, rabbithub_subscriber_contact_info)},
                      {disc_copies, DBNodes}]),
    %% Create ram_copies (default) for all other tables
    ok = create_table(rabbithub_subscription_pid,
                      [{attributes, record_info(fields, rabbithub_subscription_pid)}]),
    ok = create_table(rabbithub_subscription_err,
                      [{attributes, record_info(fields, rabbithub_subscription_err)}]),
    ok = mnesia:wait_for_tables([rabbithub_lease,
                                 rabbithub_subscription_pid,
                                 rabbithub_subscription_err, 
                                 rabbithub_subscriber_contact_info,
                                 rabbithub_outbound_auth],
                                5000),
    ok.

create_table(Name, Params) ->
    Node = node(),
    case mnesia:create_table(Name, Params) of
        {atomic, ok} ->  
            rabbit_log:info("RabbitHub created table:  ~p~n", [Name]),           	        
            ok;
        %% If table already exists, check if it exists on the local node, if not create table copy locally
        %%    Based on Params sent in, create disc_copy (explicit) or ram_copy (default)
        {aborted, {already_exists, Name}} ->                     
            Result = lists:keyfind(disc_copies, 1, Params),    
            case Result of
                {disc_copies, _Tuple} ->            
                    %% Find all disc copy nodes for this table        
                    DiscCopies = mnesia:table_info(Name, disc_copies),	                
                    
                    %% If Node is in disc copies list, it is already on this server and do nothing
                    %% If Node is not in disc copies list, create local copy of table
                    F = fun(X) -> X  == Node end,
		            case lists:any(F, DiscCopies) of		                
			            true ->			                
			                ok;
			            false ->			                
			                case mnesia:add_table_copy(Name, Node, disc_copies) of
			                    {atomic, ok} -> 
			                        rabbit_log:info("RabbitHub created table: ~p on local node ~p as a disc copy~n", [Name, Node]),
			                        ok;
			                    {aborted, R} ->
			                        rabbit_log:warning("RabbitHub failed to create table ~p on ~p as a disc copy.  Aborted Reason:  ~p~n", [Name, Node, R]),
			                        %% Do not fail startup, warning only tables are still accessible remotely
			                        ok
                            end
                    end;
                false ->      
                    %% Find all ram copy nodes for this table             
                    RamCopies = mnesia:table_info(Name, ram_copies),  
                    %% If Node is in ram copies list, it is already on this server and do nothing
                    %% If Node is not in disc copies list, create local copy of table 	                
                    F = fun(X) -> X  == Node end,
		            case lists:any(F, RamCopies) of
			            true ->			                
			                ok;
			            false ->			                
			                case mnesia:add_table_copy(Name, Node, ram_copies) of
			                    {atomic, ok} -> 
			                        rabbit_log:info("RabbitHub created table: ~p on local node ~p as a ram copy~n", [Name, Node]),
			                        ok;
			                    {aborted, R} ->
			                        rabbit_log:warning("RabbitHub failed to create table ~p on ~p as a ram copy.  Aborted with Reason:  ~p~n", [Name, Node, R]),
			                        %% Do not fail startup, warning only tables are still accessible remotely
			                        ok
                            end
                    end
            end,            
            ok;
        {aborted, Reason} -> 
            rabbit_log:info("RabbitHub failed to create table ~p.  Aborted with Reason:  ~p~n", [Name, Reason]),
            {aborted, Reason}
    end.

get_env(EnvVar, DefaultValue) ->
    case application:get_env(rabbithub, EnvVar) of
        undefined ->
            DefaultValue;
        {ok, V} ->
            V
    end.

instance_key() ->
    case application:get_env(rabbithub, instance_key) of
        undefined ->
            KeyBin = crypto:sha(term_to_binary({node(),
                                                now(),
                                                rabbit_guid:binary(rabbit_guid:gen(), "keyseed")})),
            application:set_env(rabbithub, instance_key, KeyBin),
            KeyBin;
        {ok, KeyBin} ->
            KeyBin
    end.

-record(signed_term_v1, {timestamp, nonce, term}).

sign_term(Term) ->
    Message = #signed_term_v1{timestamp = now(),
                              nonce = rabbit_guid:binary(rabbit_guid:gen(), "nonce"),
                              term = Term},
    DataBlock = zlib:zip(term_to_binary(Message)),
    Mac = crypto:sha_mac(instance_key(), DataBlock),
    20 = size(Mac), %% assertion
    <<Mac/binary, DataBlock/binary>>.

verify_term(Packet) ->
    case catch verify_term1(Packet) of
        {'EXIT', _Reason} -> {error, validation_crashed};
        Other -> Other
    end.

max_age_seconds() -> get_env(signed_term_max_age_seconds, 300).

verify_term1(<<Mac:20/binary, DataBlock/binary>>) ->
    case crypto:sha_mac(instance_key(), DataBlock) of
        Mac ->
            #signed_term_v1{timestamp = Timestamp,
                            nonce = _Nonce,
                            term = Term}
                = binary_to_term(zlib:unzip(DataBlock)),
            AgeSeconds = timer:now_diff(now(), Timestamp) div 1000000,
            TooOld = max_age_seconds(),
            if
                AgeSeconds >= TooOld ->
                    {error, expired};
                true ->
                    {ok, Term}
            end;
        _ ->
            {error, validation_failed}
    end.

%% URL-safe variant of Base64 encoding.
b64enc(IoList) ->
    S = base64:encode_to_string(IoList),
    to_urlsafe([], S).

to_urlsafe(Acc, []) ->
    lists:reverse(Acc);
to_urlsafe(Acc, [$+ | Rest]) ->
    to_urlsafe([$- | Acc], Rest);
to_urlsafe(Acc, [$/ | Rest]) ->
    to_urlsafe([$_ | Acc], Rest);
to_urlsafe(Acc, [$= | Rest]) ->
    to_urlsafe(Acc, Rest);
to_urlsafe(Acc, [C | Rest]) ->
    to_urlsafe([C | Acc], Rest).

%% URL-safe variant of Base64 decoding.
b64dec(Str) ->
    S = from_urlsafe([], 0, Str),
    base64:decode(S).

from_urlsafe(Acc, N, []) ->
    lists:reverse(case N rem 4 of
                      0 -> Acc;
                      1 -> exit({invalid_b64_length, N});
                      2 -> "==" ++ Acc;
                      3 -> "=" ++ Acc
                  end);
from_urlsafe(Acc, N, [$- | Rest]) ->
    from_urlsafe([$+ | Acc], N + 1, Rest);
from_urlsafe(Acc, N, [$_ | Rest]) ->
    from_urlsafe([$/ | Acc], N + 1, Rest);
from_urlsafe(Acc, N, [C | Rest]) ->
    from_urlsafe([C | Acc], N + 1, Rest).

canonical_scheme() -> get_env(canonical_scheme, "http").
canonical_host() -> get_env(canonical_host, "localhost").
canonical_basepath() -> get_env(canonical_basepath, "rabbithub").

default_username() -> get_env(default_username, undefined).

r(ResourceType, ResourceName) when is_list(ResourceName) ->
    r(ResourceType, list_to_binary(ResourceName));
r(ResourceType, ResourceName) ->
    rabbit_misc:r(<<"/">>, ResourceType, ResourceName).

%% BRC (want to make vhost variable)
r(VHost, ResourceType, ResourceName) when is_list(ResourceName) ->
    r(VHost, ResourceType, list_to_binary(ResourceName));
r(VHost, ResourceType, ResourceName) ->
    rabbit_misc:r(VHost, ResourceType, ResourceName).

respond_xml(Req, StatusCode, Headers, StylesheetRelUrlOrNone, XmlElement) ->
    Req:respond({StatusCode,
                 [{"Content-type", "text/xml"}] ++ Headers,
                 "<?xml version=\"1.0\"?>" ++
                   stylesheet_pi(StylesheetRelUrlOrNone) ++
                   xmerl:export_simple([XmlElement],
                                       xmerl_xml,
                                       [#xmlAttribute{name=prolog, value=""}])}).

stylesheet_pi(none) ->
    [];
stylesheet_pi(RelUrl) ->
    ["<?xml-stylesheet href=\"", RelUrl, "\" type=\"text/xsl\" ?>"].
    
format_xheader({K, _T, V}) ->
    lists:flatten(io_lib:format("~s = ~s", [K, V])).
    
format_headers(Headers) ->
    %% remove x-death headers before formatting to send to subscriber
    Headers2 = lists:keydelete(<<"x-death">>, 1, Headers),
    string:join(lists:map(fun format_xheader/1, Headers2), ", ").        

deliver_via_post(Subscription = #rabbithub_subscription{callback = Callback},
                 BasicMessage = #basic_message{routing_keys = [RoutingKeyBin | _],
                                content = Content0 = #content{payload_fragments_rev = PayloadRev}},
                 ExtraHeaders, QNameResource) ->
                 
                 
    case catch mochiweb_util:urlsplit(Callback) of
        {_Scheme, _NetLoc, _Path, ExistingQuery, _Fragment} ->         
           #content{properties = #'P_basic'{content_type = ContentTypeBin}} =
               rabbit_binary_parser:ensure_content_decoded(Content0),
           PayloadBin = list_to_binary(lists:reverse(PayloadRev)),

           C = case ExistingQuery of
                   "" -> "?";
                   _  -> "&"
               end,

		   % Get the hub.topic part of the URL if the environment variable
		   % indicates that it should be added as the PubSubHubBub specification
		   % does not require it - default is to add the topic
		   Topic = case application:get_env(rabbithub, append_hub_topic_to_callback) of
				{ok, false} ->
					"";
				_ ->
					C ++ mochiweb_util:urlencode([{'hub.topic', RoutingKeyBin}])
		   end,

           URL = Callback ++ Topic,

		   ContentType = case ContentTypeBin of
		       undefined -> "application/octet-stream";
				_ -> binary_to_list(ContentTypeBin)
		   end,           
           %% Adding options to send message_id and correlation_id as http headers to subscriber
           MsgIdHeaderName = case application:get_env(rabbithub, set_message_id) of
                {ok, MsgIdHeaderName1} -> MsgIdHeaderName1;
                undefined -> undefined
           end,
           
           MsgId = case MsgIdHeaderName of
                undefined -> undefined;
                _MsgIdHeaderName2 ->                     
                   (Content0#content.properties)#'P_basic'.message_id                
           end,
           CorrIdHeaderName = case application:get_env(rabbithub, set_correlation_id) of
                undefined -> undefined;
                {ok, CorrIdHeaderName1} -> CorrIdHeaderName1                
           end,
           CorrId =  case CorrIdHeaderName of                
                undefined -> undefined;
                _CorrIdHeaderName2 -> 
                    (Content0#content.properties)#'P_basic'.correlation_id
           end,   
           MsgHeaders = (Content0#content.properties)#'P_basic'.headers,
           
           MsgHdrs = case MsgHeaders of
                undefined -> 
                    undefined;
                _MsgHdrsTmp -> 
                    format_headers(MsgHeaders)                
           end,
           %% if a x-death header exists get the routing key, queue name and exchange name from the rejected record, otherwise
           %%  get it from the basic message and passed in queue name
           {QueueStr, ExchangeStr, RoutingKeyStr, Count} = get_queue_exchange_and_routingkey(BasicMessage, QNameResource),
           ExtraHeaders1 = case Count of
               0 -> ExtraHeaders;
               RedeliverCount -> [{"X-AMQP-Redelivered", "true"}, {"X-AMQP-Redelivered-Count", integer_to_list(RedeliverCount)}]
           end,
           
           AllHeaders = case {MsgId, CorrId, MsgHdrs} of
                {undefined, undefined, undefined} ->               
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr} | ExtraHeaders1];
					  
                {MId, undefined, undefined} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr}, 
					  {atom_to_list(MsgIdHeaderName), binary_to_list(MId)}| ExtraHeaders1];
			    {undefined, undefined, MH} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr}, 
					  {"x-rabbithub-msg_header", MH} | ExtraHeaders1];
				
				{undefined, CId, undefined} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr}, 
					  {atom_to_list(CorrIdHeaderName), binary_to_list(CId)} | ExtraHeaders1];
					  
			    {undefined, CId, MH} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr}, 
					  {atom_to_list(CorrIdHeaderName), binary_to_list(CId)}, {"x-rabbithub-msg_header", MH} | ExtraHeaders1];
					  
			    {MId, undefined, MH} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr},
					  {atom_to_list(MsgIdHeaderName), binary_to_list(MId)}, {"x-rabbithub-msg_header", MH} | ExtraHeaders1];		  
					  
		        {MId, CId, undefined} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr},
					  {atom_to_list(MsgIdHeaderName), binary_to_list(MId)}, 
					  {atom_to_list(CorrIdHeaderName), binary_to_list(CId)} | ExtraHeaders1];					  			    
									  
				{MId, CId, MH} -> 
                    [{"Content-length", integer_to_list(size(PayloadBin))},
					  {"X-AMQP-Routing-Key", RoutingKeyStr},
					  {atom_to_list(MsgIdHeaderName), binary_to_list(MId)}, {atom_to_list(CorrIdHeaderName), binary_to_list(CId)}, 
					  {"x-rabbithub-msg_header", MH} | ExtraHeaders1]					  	  
                                                		        
          end, 
          
          %% get subscription configuration for maxtps and outbound auth
          R3 = mnesia:transaction(fun () -> mnesia:read({rabbithub_lease, Subscription}) end),
          Subs = case R3 of
              {atomic, []} ->
                  [];       
              {atomic, X} ->
                  X;
              {aborted, Reason2} -> 
                  {error, Reason2}
          end,
          Sub = lists:nth(1, Subs),
          %% check if outbound authentication is configured and add appropriate headers
          ReadAuthFun = fun() ->
              case  (AuthValList = mnesia:read({rabbithub_outbound_auth, Subscription})) =:= [] of
                  true -> 
                      [];
                  false -> 
                      AuthVal = lists:nth(1, AuthValList),
                      [{"Authorization", "Basic " ++(AuthVal#rabbithub_outbound_auth.auth_config)#rabbithub_outbound_auth_basicauth_config.authorization}]
              end
          end, 
                 
          {atomic, OutboundAuth} = mnesia:transaction(ReadAuthFun),          
          
          AllHeaders1 = lists:append(AllHeaders, OutboundAuth),
          
          QueueNameHeader = [{"X-AMQP-Queue", QueueStr}],
          AllHeaders2 = lists:append(AllHeaders1, QueueNameHeader),
          ExchangeNameHeader = [{"X-AMQP-Exchange", ExchangeStr}],
          AllHeaders3 = lists:append(AllHeaders2, ExchangeNameHeader),    
		   Payload = {URL, AllHeaders3, ContentType, PayloadBin},
						 
		   % Log the request if the environment variable has been set - default
		   % is not to log the request
		   case application:get_env(rabbithub, log_http_post_request) of
				{ok, true} ->
					rabbit_log:info("RabbitHub post request~n~p~n", [Payload]);
				_ ->
					ok
		   end,
		   
		   case application:get_env(rabbithub, log_subscription_expiration) of
               {ok, Days} ->
		   	       DaysMicro = Days * 864000000,
			       ExpireRange = DaysMicro + rabbithub_subscription:system_time(), 
			       {Year, Month, Day} = microsec_to_date(Sub#rabbithub_lease.lease_expiry_time_microsec),
			       case Sub#rabbithub_lease.lease_expiry_time_microsec of
			           L1 when L1 < ExpireRange ->
			               rabbit_log:warning("RabbitHub subscriber ~p~n will expire on ~p/~p/~p~n", [Sub, Month, Day, Year]);
			           _ -> ok
			       end;
		        _ ->
		            ok
		   end,
		   
		   
           HttpReqOpts = case application:get_env(rabbithub, http_request_options) of
				{ok, Opts} ->
					Opts;
				_ ->
					[]
		   end,
		   		   
		   BeforeReqTimeMicro = rabbithub_subscription:system_time(),
		   		                                    
           HTTPResp = case httpc:request(post, Payload, HttpReqOpts, []) of
               {ok, {{_Version, StatusCode, _StatusText}, _Headers, _Body}} ->
                  if
                     StatusCode >= 200 andalso StatusCode < 300 ->
                         {ok, StatusCode};
                     true ->
                         {error, StatusCode, {{_Version, StatusCode, _StatusText}, _Headers, _Body}}
                  end;
               {error, Reason} ->
                   {error, Reason, {}}
           end,
   		   AfterReqTimeMicro = rabbithub_subscription:system_time(),
   		   
   		   %% calculate max tps
           MaxTps = Sub#rabbithub_lease.max_tps,
           case MaxTps of
               0 -> ok;
               N when N > 0 ->                   
                   %% get consumer list for this subscription
                   Con = #rabbithub_consumer{subscription = Subscription, node = '_'},    
                   WildPattern = mnesia:table_info(rabbithub_subscription_pid, wild_pattern),
                   Pattern = WildPattern#rabbithub_subscription_pid{consumer = Con},
                   F = fun() -> mnesia:match_object(Pattern) end,   
                   {atomic, Results} = mnesia:transaction(F),
                              
                   NoConsumers = length(Results),
                   ConsumerTPS = MaxTps / NoConsumers,
                   ConsumerSPT = 1 / ConsumerTPS,
                   ConsumerSPTMilli = ConsumerSPT * 1000,
                   TransactionTimeMicro = AfterReqTimeMicro - BeforeReqTimeMicro,
                   TransactionTimeMilli = TransactionTimeMicro / 1000,
                   Delay = ConsumerSPTMilli - TransactionTimeMilli,
                   case Delay of                    
                       D when D > 0 ->
                           case application:get_env(rabbithub, log_maxtps_delay) of
				               {ok, true} -> 
                                  rabbit_log:info("RabbitHub max tps of ~p with ~p consumers.  Delay ~p milliseconds~n For Subscription ~p", 
                                            [MaxTps, NoConsumers, round(Delay), Subscription]);
                               _ -> ok
                           end,
                           timer:sleep(round(Delay));
                       _ -> ok
                   end                  
           end,        
           HTTPResp;
   		   
        _ ->
            {error, invalid_callback_url, {}}
    end.
    
get_queue_exchange_and_routingkey(BasicMessage, QueueName) ->
    Content = BasicMessage#basic_message.content,
    Props = Content#content.properties,
    Headers = Props#'P_basic'.headers,
    XDeath = case Headers of
        undefined -> false;
        H -> lists:keyfind(<<"x-death">>, 1, H)
    end,
    case XDeath of
        false ->
            Ex = binary_to_list((BasicMessage#basic_message.exchange_name)#resource.name),
            Rk = binary_to_list(lists:nth(1, BasicMessage#basic_message.routing_keys)),
            Qu = binary_to_list(QueueName#resource.name),           
            {Qu, Ex, Rk, 0};
        _T -> 
            Array = element(3, XDeath),
            FindRejectedFun = fun ({table, Info}, Resp) -> 
                case lists:keyfind(<<"rejected">>, 3, Info) of
                    false -> 
                        case Resp of
                            undefined -> undefined;
                            Val -> Val
                        end;
                    _Tuple ->  Info
                end
            end,
            RetList = lists:foldl(FindRejectedFun, undefined, Array),
            Queue = binary_to_list(element(3,lists:keyfind(<<"queue">>, 1, RetList))),
            Exchange = binary_to_list(element(3,lists:keyfind(<<"exchange">>, 1, RetList))),
            RoutingKey = binary_to_list(element(2, lists:nth(1, element(3,lists:keyfind(<<"routing-keys">>, 1, RetList))))),
            Count = element(3,lists:keyfind(<<"count">>, 1, RetList)),
            {Queue, Exchange, RoutingKey, Count }
    end.    


microsec_to_date(Microseconds) ->
   BaseDate      = calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
   Seconds       = BaseDate + (Microseconds div 1000000),
   { Date,_Time} = calendar:gregorian_seconds_to_datetime(Seconds),
   Date.

error_and_delete_sub(Subscription, ErrorReport) ->
    rabbit_log:error("RabbitHub error~n~p~n", [ErrorReport]),
	rabbithub_subscription:delete(Subscription).

error_and_unsub(Subscription, ErrorReport) ->
    {atomic, AppName} = mnesia:transaction(fun () ->
         case mnesia:read(rabbithub_subscriber_contact_info, Subscription) of
            [] -> application_unknown;
            [Record] -> (Record#rabbithub_subscriber_contact_info.contact_info)#rabbithub_contact.app_name
         end
    end),
    rabbit_log:error("RabbitHub Subscriber Deactivated.~nApplication: ~p~nSubscriber: ~p~nError: ~p~n", [AppName, Subscription, ErrorReport]),
	%% If unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_milliseconds
	%%  are set then unsubscribe_on_http_post_error is not allowed to override.
	%%
	%%  If they are not set check the environment variable unsubscribe_on_http_post_error to 
	%%  determine if the subscription should be deleted or not - default 
	%%  is to unsubscribe on any post error
	case application:get_env(rabbithub, unsubscribe_on_http_post_error_limit) of
        {ok, ErrorLimit} when is_integer(ErrorLimit)->
            case application:get_env(rabbithub, unsubscribe_on_http_post_error_timeout_milliseconds) of
                {ok, ErrorTimeout} when is_integer(ErrorTimeout)->  
                   rabbithub_subscription:deactivate(Subscription),
                   rabbithub_web:deactivate_ha_consumers(Subscription);
                _ -> 
                    case application:get_env(rabbithub, unsubscribe_on_http_post_error) of
		                {ok, false} ->
			                ok;
		                _ ->
		                  rabbithub_subscription:deactivate(Subscription),
		                  rabbithub_web:deactivate_ha_consumers(Subscription)
	                end
	        end;
        _ ->
		    case application:get_env(rabbithub, unsubscribe_on_http_post_error) of
		        {ok, false} ->
			        ok;
		        _ ->
		            rabbithub_subscription:deactivate(Subscription),
		            rabbithub_web:deactivate_ha_consumers(Subscription)
	        end
	end,
    ok.
