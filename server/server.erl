-module(server).
-export([start/1, stop/1]).

start(Port) ->
    % Arranque dos serviços de gestão de ficheiros
    UsersFMPid = files_manager:start("users.bin"),
    ScoresFMPid = files_manager:start("scores.bin"),

    % Load dos estados iniciais dos ficheiros
    Accounts = files_manager:load(UsersFMPid),
    InitialScores = files_manager:load(ScoresFMPid),

    % Arranque do serviço de login
    login_manager:start(Accounts, UsersFMPid),

    % Arranque do serviço de gestão de pontuações
    scores_manager:start(InitialScores, ScoresFMPid),

    % Arranque do serviço de matchmaking
    matchmaker:start(),

    % Guardar pid do server
    Pid = spawn(fun() -> server(Port, UsersFMPid, ScoresFMPid) end),
    register(?MODULE, Pid),
    % Retornar pid para o poder guardar na shell do erl
    Pid.

stop(Server) ->
    Server ! stop.

server(Port, UsersFMPid, ScoresFMPid) ->
    {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
    AcceptorPid = spawn(fun() -> acceptor(LSock) end),
    receive
        stop ->
            % Fechar o LSock
            gen_tcp:close(LSock),
            % Matar o acceptor, por segurança
            exit(AcceptorPid, shutdown),
            % Parar os outros serviços/processos de forma ordenada
            login_manager:stop(),
            scores_manager:stop(),
            matchmaker:stop(),
            files_manager:stop(UsersFMPid),
            files_manager:stop(ScoresFMPid),
            io:format("SERVER: Stopped.~n")
    end.

acceptor(LSock) ->
    case gen_tcp:accept(LSock) of
        {ok, Sock} ->
            spawn(fun() -> acceptor(LSock) end),
            user_not_auth(Sock);
        {error, closed} ->
            % LSock foi fechado
            ok;
        {error, Reason} ->
            io:format("ACCEPTOR: Unexpected error ~p~n", [Reason])
    end.

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
                            gen_tcp:send(Sock, <<"REGISTER_FAIL,user_exists\n">>),
                            user_not_auth(Sock);
                        ok ->
                            gen_tcp:send(Sock, <<"REGISTER_OK\n">>),
                            scores_manager:register_user(Username),
                            user_not_auth(Sock)
                    end;
                % LOGIN,username,password
                ["LOGIN", Username, Password] ->
                    Response = login_manager:login(Username, Password),
                    case Response of
                        ok ->
                            gen_tcp:send(Sock, <<"LOGIN_OK\n">>),
                            user_auth(Sock, Username);
                        user_already_logged_in ->
                            gen_tcp:send(Sock, <<"LOGIN_FAIL,user_already_logged_in\n">>),
                            user_not_auth(Sock);
                        _ ->
                            gen_tcp:send(Sock, <<"LOGIN_FAIL,invalid_credentials\n">>),
                            user_not_auth(Sock)
                    end;
                % DELETE_ACCOUNT,username,password
                ["DELETE_ACCOUNT", Username, Password] ->
                    io:format("SERVER: User ~p requested to delete his account~n", [Username]),
                    Response = login_manager:close_account(Username, Password),
                    case Response of
                        ok ->
                            gen_tcp:send(Sock, <<"DELETE_OK\n">>),
                            scores_manager:delete_user(Username),
                            user_not_auth(Sock);
                        invalid ->
                            gen_tcp:send(Sock, <<"DELETE_FAIL,invalid_credentials\n">>),
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
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            case string:split(Line, ",", all) of
                ["PLAY"] ->
                    io:format("SERVER: User ~p wants to play~n", [Username]),
                    gen_tcp:send(Sock, <<"PLAY_OK\n">>),
                    waiting_for_game(Sock, Username);
                ["SCOREBOARD"] ->
                    io:format("SERVER: User ~p requested the scoreboard~n", [Username]),
                    % Obter a scoreboard do scores_manager e enviar
                    send_scoreboard(Sock),
                    user_auth(Sock, Username);
                ["LOGOUT"] ->
                    login_manager:logout(Username),
                    gen_tcp:send(Sock, <<"LOGOUT_OK\n">>),
                    user_not_auth(Sock);
                ["ONLINE"] ->
                    io:format("SERVER: User ~p requested the list of online users~n", [Username]),
                    OnlineUsers = login_manager:online(),
                    Payload = lists:foldl(fun(U, Acc) -> Acc ++ U ++ "\n" end, "", OnlineUsers),
                    gen_tcp:send(Sock, list_to_binary(Payload)),
                    user_auth(Sock, Username);
                _ ->
                    user_auth(Sock, Username)
            end;
        {tcp_closed, _} ->
            io:format("SERVER: User ~p disconnected...~n", [Username]),
            login_manager:logout(Username),
            ok;
        {tcp_error, _, _} ->
            ok
    end.

waiting_for_game(Sock, Username) ->
    % Entrar na fila de matchmaking
    matchmaker:join({self(), Username}),
    io:format("SERVER: User ~p joined the matchmaking queue~n", [Username]),

    % Enviar scoreboard
    send_scoreboard(Sock),

    % Garantir exibição mínima de 2 segundos antes de aceitar game_started
    MinDisplayUntil = erlang:system_time(millisecond) + 2000,

    waiting_loop(Sock, Username, MinDisplayUntil).

waiting_loop(Sock, Username, MinDisplayUntil) ->
    % Esperar por feedback do matchmaker
    receive
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            case string:split(Line, ",", all) of
                ["LEAVE"] ->
                    matchmaker:leave({self(), Username}),
                    user_auth(Sock, Username);
                _ ->
                    ok
            end;
        {game_started, GamePid, Data} ->
            io:format("SERVER: Game started for user ~p~n", [Username]),
            % Esperar o tempo mínimo se ainda não passou
            Now = erlang:system_time(millisecond),
            case MinDisplayUntil - Now of
                Delay when Delay > 0 -> timer:sleep(Delay);
                _ -> ok
            end,
            % Enviar mensagem separada para garantir mudança de screen no client
            gen_tcp:send(Sock, <<"GAME_START\n">>),
            gen_tcp:send(Sock, Data),
            in_game(Sock, Username, GamePid);
        {waiting_other_players, WPSize} ->
            % Informar o jogador que está à espera
            Payload = io_lib:format("WAITING_OTHER_PLAYERS,~b\n", [WPSize]),
            gen_tcp:send(Sock, list_to_binary(Payload)),
            waiting_loop(Sock, Username, MinDisplayUntil);
        {gaming_starting_soon, WPSize} ->
            % Informar o jogador que o jogo está quase a começar
            Payload = io_lib:format("GAME_STARTING_SOON,~b\n", [WPSize]),
            gen_tcp:send(Sock, list_to_binary(Payload)),
            waiting_loop(Sock, Username, MinDisplayUntil);
        {active_games_full, _} ->
            % Informar o jogador que está à espera por falta de slots
            gen_tcp:send(Sock, <<"ACTIVE_GAMES_FULL\n">>),
            waiting_loop(Sock, Username, MinDisplayUntil);
        {tcp_closed, _} ->
            % Notificar o matchmaker para remover o jogador da fila
            matchmaker:leave({self(), Username}),
            login_manager:logout(Username),
            ok;
        {error, Reason} ->
            {Reason, ok}
    end.

in_game(Sock, Username, GamePid) ->
    receive
        {tcp, _, Data} ->
            Line = string:trim(binary_to_list(Data)),
            % Enviar comandos do jogador para o processo do jogo
            case string:split(Line, ",", all) of
                ["INPUT", L, U, R] ->
                    GamePid ! {input, self(), {to_bool(L), to_bool(U), to_bool(R)}},
                    in_game(Sock, Username, GamePid);
                _ ->
                    in_game(Sock, Username, GamePid)
            end;
        {delta_update, Data} ->
            io:format("SERVER: Sending Delta update for user ~p~n", [Username]),
            gen_tcp:send(Sock, Data),
            in_game(Sock, Username, GamePid);
        {game_over, Result, ScoreboardStr} ->
            Payload = io_lib:format("GAME_OVER,~s,~s\n", [Result, ScoreboardStr]),
            gen_tcp:send(Sock, list_to_binary(Payload)),
            user_auth(Sock, Username);
        {tcp_closed, _} ->
            io:format("SERVER: User ~p disconnected...~n", [Username]),
            login_manager:logout(Username),
            ok;
        {tcp_error, _, _} ->
            ok
    end.

%% Funções auxiliares
to_bool("1") -> true;
to_bool(_) -> false.

send_scoreboard(Sock) ->
    case scores_manager:get_scoreboard(self()) of
        {ok, Top10} ->
            Top10Str = [io_lib:format("~s:~p", [U, S]) || {U, S} <- Top10],
            Payload = ["SCOREBOARD_OK,", string:join(Top10Str, ","), "\n"],
            gen_tcp:send(Sock, list_to_binary(Payload));
        {error, timeout} ->
            gen_tcp:send(Sock, <<"SCOREBOARD_FAIL,timeout\n">>)
    end.
