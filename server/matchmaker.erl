% O matchmaker é responsável por gerir as partidas ativas e os jogadores que estão à
% espera de uma partida
-module(matchmaker).
-export([start/0, stop/0, join/1, leave/1]).

% loop(Queue de jogadores, número de jogos ativos, referência do timer)
start() ->
    Pid = spawn(fun() -> loop([], 0, undefined) end),
    register(?MODULE, Pid).

stop() -> ?MODULE ! stop.

join(Player) ->
    ?MODULE ! {join, Player}.

leave(PlayerPid) ->
    ?MODULE ! {leave, PlayerPid}.

% Documentação sobre timers:
% Creating timers using erlang:send_after/3 and erlang:start_timer/3,
% is more efficient than using the timers provided by the timer module in STDLIB.
loop(WaitingPlayers, ActiveGames, TimerRef) ->
    receive
        % Terminar processo matchmaker
        stop ->
            io:format("MATCHMAKER: Shutting down...~n"),
            ok;
        {join, {PlayerPid, Username}} ->
            NewWaitingPlayers = WaitingPlayers ++ [{PlayerPid, Username}],
            WPSize = length(NewWaitingPlayers),
            io:format("MATCHMAKER: ~p joined. Waiting players: ~p~n", [Username, NewWaitingPlayers]),
            if
                WPSize =:= 4 andalso ActiveGames < 4 ->
                    % Se existir um timer ativo, cancelá-lo
                    if
                        TimerRef =/= undefined -> erlang:cancel_timer(TimerRef);
                        true -> ok
                    end,
                    {Players, Rest} = lists:split(4, NewWaitingPlayers),
                    io:format("MATCHMAKER: Starting game with players: ~p~n", [Players]),
                    game_session:start_game(Players, self()),
                    loop(Rest, ActiveGames + 1, undefined);
                % Verificar se o timer já existe para evitar criar múltiplos timers desnecessários
                WPSize =:= 3 andalso ActiveGames < 4 andalso
                    TimerRef =:= undefined ->
                    % Se temos 3 jogadores à espera e nenhum timer ativo, criar timer
                    % e enviar mensagem start_game após 10 segundos
                    io:format("MATCHMAKER: 3 players waiting. Starting timer...~n"),
                    TRef = erlang:send_after(10000, self(), start_game),
                    loop(NewWaitingPlayers, ActiveGames, TRef);
                ActiveGames >= 4 ->
                    io:format(
                        "MATCHMAKER: Can't start another game. ~b games already running...~n", [
                            ActiveGames
                        ]
                    ),
                    PlayerPid ! {active_games_full, ActiveGames},
                    loop(NewWaitingPlayers, ActiveGames, TimerRef);
                true ->
                    io:format(
                        "MATCHMAKER: Not enough players to start a game. Waiting players: ~p~n",
                        [NewWaitingPlayers]
                    ),
                    PlayerPid ! {waiting_other_players, WPSize},
                    loop(NewWaitingPlayers, ActiveGames, TimerRef)
            end;
        {leave, PlayerPid} ->
            NewWaitingPlayers = lists:keydelete(PlayerPid, 1, WaitingPlayers),
            loop(NewWaitingPlayers, ActiveGames, TimerRef);
        start_game ->
            % Verificar novamente se há jogadores suficientes
            case length(WaitingPlayers) >= 3 of
                true ->
                    {Players, Rest} = lists:split(3, WaitingPlayers),
                    io:format("MATCHMAKER: Starting game with players: ~p~n", [Players]),
                    game_session:start_game(Players, self()),
                    loop(Rest, ActiveGames + 1, undefined);
                false ->
                    loop(WaitingPlayers, ActiveGames, TimerRef)
            end;
        game_finished ->
            io:format("MATCHMAKER: Game finished. Active games: ~p~n", [ActiveGames - 1]),
            loop(WaitingPlayers, ActiveGames - 1, TimerRef)
    end.
