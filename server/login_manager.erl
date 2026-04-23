% Serviço singleton para fazer a gestão de contas e sessões de login
-module(login_manager).
-export([
    create_account/2,
    close_account/2,
    login/2,
    logout/1,
    online/0,
    start/2,
    loop/2,
    stop/0
]).

% Remote procedure call
rpc(Request) ->
    ?MODULE ! {Request, self()},
    receive
        {?MODULE, Res} -> Res
    end.

create_account(Username, Password) ->
    rpc({create_account, Username, Password}).

close_account(Username, Password) ->
    rpc({close_account, Username, Password}).

login(Username, Password) ->
    rpc({login, Username, Password}).

logout(Username) ->
    rpc({logout, Username}).

online() ->
    rpc(online).

% Envio de uma mensagem simples de controlo, assíncrona, para evitar deadlocks.
% Usar o rpc poderia causar um deadlock caso o processo login_manager terminasse
% antes da resposta ser recebida pelo servidor.
% Nesse caso, o servidor ficaria bloqueado à espera de uma resposta que nunca chegaria.
stop() ->
    ?MODULE ! stop.

start(Accounts, UsersFileManagerPid) ->
    % Mapa para guardar sessões ativas (Username -> true/false)
    Sessions = #{},
    Pid = spawn(fun() -> loop({Accounts, Sessions}, UsersFileManagerPid) end),
    register(?MODULE, Pid).

loop({Accounts, Sessions}, UsersFileManagerPid) ->
    receive
        stop ->
            % Gravar o estado atual antes de parar o processo
            files_manager:save(UsersFileManagerPid, Accounts),
            io:format("LOGIN_MANAGER: final state saved. Shutting down...~n"),
            ok;
        {Request, From} ->
            {Res, NextState} = handle(Request, {Accounts, Sessions}, UsersFileManagerPid),
            From ! {?MODULE, Res},
            loop(NextState, UsersFileManagerPid)
    end.

% CREATE ACCOUNT
handle({create_account, Username, Password}, {Accounts, Sessions}, UsersFileManagerPid) ->
    case maps:find(Username, Accounts) of
        error ->
            NewAccounts = maps:put(Username, Password, Accounts),
            files_manager:save(UsersFileManagerPid, NewAccounts),
            {ok, {NewAccounts, Sessions}};
        {ok, _} ->
            {user_exists, {Accounts, Sessions}}
    end;
% CLOSE ACCOUNT
handle({close_account, Username, Password}, {Accounts, Sessions}, UsersFileManagerPid) ->
    case maps:find(Username, Accounts) of
        {ok, Password} ->
            NewAccounts = maps:remove(Username, Accounts),
            files_manager:save(UsersFileManagerPid, NewAccounts),
            {ok, {NewAccounts, Sessions}};
        _ ->
            {invalid, {Accounts, Sessions}}
    end;
% LOGIN
handle({login, Username, Password}, {Accounts, Sessions}, _) ->
    case maps:find(Username, Accounts) of
        {ok, Password} ->
            case maps:find(Username, Sessions) of
                {ok, true} ->
                    {user_already_logged_in, {Accounts, Sessions}};
                _ ->
                    {ok, {Accounts, maps:put(Username, true, Sessions)}}
            end;
        _ ->
            {invalid, {Accounts, Sessions}}
    end;
% LOGOUT
handle({logout, Username}, {Accounts, Sessions}, _) ->
    case maps:find(Username, Sessions) of
        {ok, true} ->
            {ok, {Accounts, maps:remove(Username, Sessions)}};
        _ ->
            {ok, {Accounts, Sessions}}
    end;
% ONLINE USERS
handle(online, {Accounts, Sessions}, _) ->
    OnlineUsers = maps:keys(Sessions),
    {OnlineUsers, {Accounts, Sessions}}.
