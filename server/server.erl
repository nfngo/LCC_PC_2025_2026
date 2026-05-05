-module(server).
-export([start/1, stop/1]).

start(Port) ->
    % Arranque dos serviços de gestão de ficheiros
    UsersFMPid = files_manager:start("users.bin"),
    % ScoresFMPid = files_manager:start("scores.bin"),

    % Load dos estados iniciais dos ficheiros
    Accounts = files_manager:load(UsersFMPid),
    % InitialScores = files_manager:load(ScoresFMPid),

    % Arranque do serviço de login
    login_manager:start(Accounts, UsersFMPid),

    % Arranque do serviço de matchmaking
    matchmaker:start(),

    spawn(fun() -> server(Port) end).

stop(Server) ->
    login_manager:stop(),
    matchmaker:stop(),
    % Registar o pid do UsersFM para ter acesso?
    % files_manager:stop(users_fm_pid),
    Server ! stop.

server(Port) ->
    {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
    spawn(fun() -> acceptor(LSock) end),
    receive
        stop -> ok
    end.

acceptor(LSock) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    spawn(fun() -> acceptor(LSock) end),
    user_not_auth(Sock).

user_not_auth(Sock) ->
    receive
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            case string:split(Line, ",", all) of
                % REGISTER,username,password
                ["REGISTER", Username, Password] ->
                    Response = login_manager:create_account(Username, Password),
                    case Response of
                        user_exists ->
                            gen_tcp:send(Sock, "REGISTER_FAIL,user_exists\n"),
                            user_not_auth(Sock);
                        ok ->
                            gen_tcp:send(Sock, "REGISTER_OK\n"),
                            user_not_auth(Sock)
                    end;
                % LOGIN,username,password
                ["LOGIN", Username, Password] ->
                    Response = login_manager:login(Username, Password),
                    case Response of
                        ok ->
                            gen_tcp:send(Sock, "LOGIN_OK\n"),
                            user_auth(Sock, Username);
                        user_already_logged_in ->
                            gen_tcp:send(Sock, "LOGIN_FAIL,user_already_logged_in\n"),
                            user_not_auth(Sock);
                        _ ->
                            gen_tcp:send(Sock, "LOGIN_FAIL,invalid_credentials\n"),
                            user_not_auth(Sock)
                    end;
                ["DELETE_ACCOUNT", Username, Password] ->
                    io:format("SERVER: User ~p requested to delete his account~n", [Username]),
                    Response = login_manager:close_account(Username, Password),
                    case Response of
                        ok ->
                            gen_tcp:send(Sock, "DELETE_OK\n"),
                            user_not_auth(Sock);
                        invalid ->
                            gen_tcp:send(Sock, "DELETE_FAIL,invalid_credentials\n"),
                            user_not_auth(Sock)
                    end;
                _ ->
                    user_not_auth(Sock)
            end;
        {tcp_closed, _} ->
            ok;
        {tcp_error, _} ->
            ok
    end.

user_auth(Sock, Username) ->
    receive
        {line, Data} ->
            gen_tcp:send(Sock, Data),
            user_auth(Sock, Username);
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            case string:split(Line, ",", all) of
                ["PLAY"] ->
                    io:format("SERVER: User ~p wants to play~n", [Username]),
                    waiting_for_game(Sock, Username);
                ["SCOREBOARD"] ->
                    % Implementar lógica de envio do scoreboard
                    io:format("SERVER: User ~p requests the scoreboard~n", [Username]),
                    user_auth(Sock, Username);
                ["LOGOUT"] ->
                    login_manager:logout(Username),
                    gen_tcp:send(Sock, "LOGOUT_OK\n"),
                    user_not_auth(Sock);
                ["ONLINE"] ->
                    OnlineUsers = login_manager:online(),
                    Response = lists:foldl(fun(U, Acc) -> Acc ++ U ++ "\n" end, "", OnlineUsers),
                    gen_tcp:send(Sock, Response),
                    user_auth(Sock, Username);
                _ ->
                    gen_tcp:send(Sock, Line),
                    user_auth(Sock, Username)
            end;
        {tcp_closed, _} ->
            ok;
        {tcp_error, _, _} ->
            ok
    end.

waiting_for_game(Sock, Username) ->
    % Entrar na fila de matchmaking
    matchmaker:join(self()),
    io:format("SERVER: User ~p joined the matchmaking queue~n", [Username]),

    % Esperar por feedback do matchmaker
    receive
        {game_started, GamePid} ->
            io:format("SERVER: Game started for user ~p~n", [Username]),
            gen_tcp:send(Sock, "GAME_STARTED\n"),
            in_game(Sock, Username, GamePid);
        {error, Reason} ->
            {Reason, ok}
    end.

in_game(Sock, Username, GamePid) ->
    receive
        {game_over, Score} ->
            io:format("SERVER: Game over for user ~p. Score: ~p~n", [Username, Score]),
            gen_tcp:send(Sock, io_lib:format("GAME_OVER,~p\n", [Score])),
            user_auth(Sock, Username);
        {line, Data} ->
            gen_tcp:send(Sock, Data),
            in_game(Sock, Username, GamePid);
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            % Enviar comandos do jogador para o processo do jogo
            case string:split(Line, ",", all) of
                ["INPUT", Directions] ->
                    GamePid ! {input, self(), Directions},
                    in_game(Sock, Username, GamePid);
                _ ->
                    in_game(Sock, Username, GamePid)
            end;
        {tcp_closed, _} ->
            ok;
        {tcp_error, _, _} ->
            ok
    end.
