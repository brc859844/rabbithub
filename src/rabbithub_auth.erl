-module(rabbithub_auth).

-include_lib("rabbit-common/include/rabbit.hrl").
-include_lib("rabbit-common/include/rabbit_framing.hrl").

-export([check_authentication/2, check_authorization/5, check_authentication_and_roles/3]).

check_authentication(Req, Fun) ->
    case Req:get_header_value("authorization") of
        undefined ->
            case rabbithub:default_username() of
                undefined ->
                    request_auth(Req);
                Username ->
                    Fun(Username)
            end;
        "Basic " ++ AuthInfo ->            
            case check_auth_info(AuthInfo) of
                {ok, Username} ->
                    Fun(Username);
                {error, _Reason} ->
                    forbidden(Req)
            end
    end.
    
check_authentication_and_roles(Req, RolesList, Fun) ->
    case Req:get_header_value("authorization") of
        undefined ->
            case rabbithub:default_username() of
                undefined ->
                    request_auth(Req);
                Username ->
                    case check_authn_roles(Username, RolesList) of
                        {ok, user} -> Fun(Username);
                        {error, _Reason} -> forbidden(Req)
                    end
            end;
        "Basic " ++ AuthInfo ->            
            case check_auth_info(AuthInfo) of
                {ok, Username} ->
                    case check_authn_roles(Username, RolesList) of
                        {ok, user} -> Fun(Username);
                        {error, _Reason} -> forbidden(Req)
                    end;
                {error, _Reason} ->
                    forbidden(Req)
            end
    end.    

check_authn_roles(Uname, Roles) ->
    case catch rabbit_access_control:check_user_login(list_to_binary(Uname), []) of
        {'EXIT', {amqp, access_refused, _, _}} ->
            {error, access_refused};
        {refused, _, _, _} ->
            {error, access_refused};                                                     
%%        {ok,{user,_,_,_}} -> 
        {ok,{user,_A,B,_C}} -> 
            case lists:all(fun(X) -> lists:member(X, B) end, Roles) of
                true  -> 
                    {ok, user};
                false -> 
                    {error, access_refused}
            end;
        _ ->
            {error, access_refused}
    end.
    
    
check_authorization(Req, Resource, Username, PermissionsRequired, Fun) ->
    CheckResults = [catch rabbit_access_control:check_resource_access(
                            #user{username = list_to_binary(Username),
                                         authz_backends =[{rabbit_auth_backend_internal, none}]},
			                 Resource, P)
			|| P <- PermissionsRequired],
    case lists:foldl(fun check_authorization_result/2, ok, CheckResults) of
        ok ->
            Fun();
        failed ->
            forbidden(Req)
    end.

check_authorization_result({'EXIT', _}, ok) ->
    failed;
check_authorization_result(ok, ok) ->
    ok;
check_authorization_result(_, failed) ->
    failed.

forbidden(Req) ->
    Req:respond({403, [], "Forbidden"}).

request_auth(Req) ->
    Req:respond({401, [{"WWW-Authenticate", "Basic realm=\"rabbitmq\""}],
                 "Authentication required."}).
%% Updated code for new response from rabbit_access_control:check_user_pass_login
%% also directly check for {ok,...) response for valid credentials and default to 
%% access_refused when an unknown response comes back
check_auth_info(AuthInfo) ->
    {User, Pass} = case string:tokens(base64:decode_to_string(AuthInfo), ":") of
                       [U, P] -> {U, P};
                       [U] -> {U, ""}
                   end,
    case catch rabbit_access_control:check_user_pass_login(list_to_binary(User),
                                                     list_to_binary(Pass)) of
        {'EXIT', {amqp, access_refused, _, _}} ->
            {error, access_refused};
        {refused, _, _, _} ->
            {error, access_refused};                                                     
%%        {ok,{user,_,_,_}} -> 
        {ok,{user,_A,_B,_C}} -> 
            {ok, User};
        _ ->
            {error, access_refused}
    end.
