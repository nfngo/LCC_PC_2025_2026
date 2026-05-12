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

    spawn(fun() -> server(Port) end).

stop(Server) ->
    login_manager:stop(),
    matchmaker:stop(),
    scores_manager:stop(),
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
        {game_started, GamePid, Data} ->
            io:format("SERVER: Game started for user ~p~n", [Username]),
            % Esperar o tempo mínimo se ainda não passou
            Now = erlang:system_time(millisecond),
            case MinDisplayUntil - Now of
                Delay when Delay > 0 -> timer:sleep(Delay);
                _ -> ok
            end,
            gen_tcp:send(Sock, Data),
            in_game(Sock, Username, GamePid);
        {waiting_other_players, WPSize} ->
            io:format("SERVER: ~b waiting players~n", [WPSize]),
            gen_tcp:send(Sock, <<"WAITING_OTHER_PLAYERS\n">>),
            waiting_loop(Sock, Username, MinDisplayUntil);
        {active_games_full, _} ->
            % Informar o cliente que está à espera por falta de slots
            gen_tcp:send(Sock, <<"ACTIVE_GAMES_FULL\n">>),
            waiting_loop(Sock, Username, MinDisplayUntil);
        {tcp_closed, _} ->
            % Notificar o matchmaker para remover o jogador da fila
            matchmaker:leave(self()),
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
            Msg = ["SCOREBOARD_OK,", string:join(Top10Str, ","), "\n"],
            gen_tcp:send(Sock, list_to_binary(Msg));
        {error, timeout} ->
            gen_tcp:send(Sock, <<"SCOREBOARD_FAIL,timeout\n">>)
    end.
