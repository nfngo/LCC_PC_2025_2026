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
                    % Obter a scoreboard do scores_manager
                    Response = scores_manager:get_scoreboard(self()),
                    case Response of
                        {ok, Top10} ->
                            % Formatar a resposta para enviar ao cliente
                            Top10Str = [io_lib:format("~s:~p", [U, S]) || {U, S} <- Top10],
                            FinalRes = ["SCOREBOARD_OK,", string:join(Top10Str, ";"), "\n"],
                            gen_tcp:send(Sock, list_to_binary(FinalRes));
                        {error, timeout} ->
                            gen_tcp:send(Sock, <<"SCOREBOARD_FAIL,timeout\n">>)
                    end,
                    user_auth(Sock, Username);
                ["LOGOUT"] ->
                    login_manager:logout(Username),
                    gen_tcp:send(Sock, <<"LOGOUT_OK\n">>),
                    user_not_auth(Sock);
                ["ONLINE"] ->
                    io:format("SERVER: User ~p requested the list of online users~n", [Username]),
                    OnlineUsers = login_manager:online(),
                    Response = lists:foldl(fun(U, Acc) -> Acc ++ U ++ "\n" end, "", OnlineUsers),
                    gen_tcp:send(Sock, list_to_binary(Response)),
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
    matchmaker:join({self(), Username}),
    io:format("SERVER: User ~p joined the matchmaking queue~n", [Username]),

    % Esperar por feedback do matchmaker
    receive
        {game_started, GamePid, Data} ->
            io:format("SERVER: Game started for user ~p~n", [Username]),
            gen_tcp:send(Sock, Data),
            in_game(Sock, Username, GamePid);
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
                    io:format("SERVER: Received input from user ~p: L=~p, U=~p, R=~p~n", [
                        Username, L, U, R
                    ]),
                    GamePid ! {input, self(), {to_bool(L), to_bool(U), to_bool(R)}},
                    in_game(Sock, Username, GamePid);
                _ ->
                    in_game(Sock, Username, GamePid)
            end;
        {delta_update, Data} ->
            gen_tcp:send(Sock, Data),
            io:format("SERVER: Sending Delta update for user ~p~n", [Username]),
            in_game(Sock, Username, GamePid);
        {game_over, ScoreboardStr, Result} ->
            Response = io_lib:format("GAME_OVER,~s,~s\n", [Result, ScoreboardStr]),
            gen_tcp:send(Sock, list_to_binary(Response)),
            user_auth(Sock, Username);
        {tcp_closed, _} ->
            ok;
        {tcp_error, _, _} ->
            ok
    end.

to_bool("1") -> true;
to_bool(_) -> false.
