-module(game_session).
-export([start_game/2, init/2]).
-include("game_entities.hrl").
-include("game_constants.hrl").

start_game(Participants, MatchmakerPid) ->
    spawn(fun() -> init(Participants, MatchmakerPid) end).

init(Participants, MatchmakerPid) ->
    % Inicializar avatares dos jogadores
    Players = create_players(Participants),
    io:format("GAME_SESSION: players:\n ~p~n", [Players]),

    % Inicializar Foods (inicialmente 12)
    FoodsList = [game_logic:create_food() || _ <- lists:seq(1, 12)],
    Foods = maps:from_list([{F#food.id, F} || F <- FoodsList]),
    io:format("GAME_SESSION: foods:\n ~p~n", [Foods]),

    % Inicializar Poisons (inicialmente 15)
    PoisonsList = [game_logic:create_poison() || _ <- lists:seq(1, 15)],
    Poisons = maps:from_list([{P#poison.id, P} || P <- PoisonsList]),
    io:format("GAME_SESSION: poisons:\n ~p~n", [Poisons]),

    % Criar timestamp para permitir interpolação no cliente
    TimeStamp = erlang:system_time(millisecond),

    % Serializar o estado inicial
    InitialState = game_serialization:serialize_world(Players, Foods, Poisons),

    % Notificar jogadores
    maps:foreach(
        fun(Pid, P) ->
            Header = io_lib:format("STATE,TS,~b;ID,~p;", [TimeStamp, P#player.id]),
            Pid ! {game_started, self(), list_to_binary([Header, InitialState, ";\n"])}
        end,
        Players
    ),

    % Inicializar pontuações dos jogadores
    InitialScores = maps:from_list([{P#player.username, 0} || P <- maps:values(Players)]),

    % Enviar a mensagem 'tick' para este processo (self()) a cada 50ms
    TimerRef = timer:send_interval(?TICK_INTERVAL, self(), tick),

    loop(Players, Foods, Poisons, InitialScores, MatchmakerPid, ?GAME_TIME, TimerRef).

% Criar jogadores e atribui posições iniciais no mapa
create_players(Participants) ->
    NumPlayers = length(Participants),
    Positions = game_logic:calculate_spawn_positions(NumPlayers, 200),

    Ids = lists:seq(1, NumPlayers),

    maps:from_list(
        [
            {Pid, game_logic:create_player(Id, Pos, Username)}
         || {{Pid, Username}, Id, Pos} <- lists:zip3(Participants, Ids, Positions)
        ]
    ).

loop(Players, Foods, Poisons, GameScores, MatchmakerPid, TimeLeft, TimerRef) ->
    receive
        {input, PlayerPid, {Left, Up, Right}} ->
            case maps:find(PlayerPid, Players) of
                {ok, Player} ->
                    % Criar uma versão atualizada apenas com os novos estados
                    NewPlayer = Player#player{
                        moving_up = Up,
                        moving_left = Left,
                        moving_right = Right
                    },
                    % Guardar no mapa e continuar o loop
                    NewPlayers = maps:put(PlayerPid, NewPlayer, Players),
                    io:format("GAME_SESSION: updated player ~p~n", [NewPlayer#player.username]),
                    loop(NewPlayers, Foods, Poisons, GameScores, MatchmakerPid, TimeLeft, TimerRef);
                error ->
                    loop(Players, Foods, Poisons, GameScores, MatchmakerPid, TimeLeft, TimerRef)
            end;
        tick ->
            % Calcular quanto tempo falta
            NewTimeLeft = TimeLeft - ?TICK_INTERVAL,

            if
                % Se o tempo acabou, terminar o jogo
                NewTimeLeft =< 0 ->
                    timer:cancel(TimerRef),
                    end_game(Players, GameScores, MatchmakerPid);
                true ->
                    % Processar o movimento de cada jogador e obter os jogadores que se moveram
                    NewPlayers = process_movement(Players),

                    % Verificar colisões
                    {FinalPlayers, Hunters, NewFoods, NewPoisons, RemovedIDs} = check_collisions(
                        NewPlayers, Foods, Poisons
                    ),

                    io:format("GAME_SESSION: Final players:\n ~p~n", [FinalPlayers]),

                    % Verificar quais jogadores foram atualizados
                    UpdatedPlayers = check_updated_players(Players, FinalPlayers),

                    io:format("GAME_SESSION: Updated players:\n ~p~n", [UpdatedPlayers]),

                    % Atualizar pontuações dos jogadores que comeram outros jogadores
                    NewGameScores = lists:foldl(
                        fun(User, GameScoresAcc) ->
                            CurrentScore = maps:get(User, GameScoresAcc, 0),
                            maps:put(User, CurrentScore + 1, GameScoresAcc)
                        end,
                        GameScores,
                        Hunters
                    ),

                    % Obter raio do menor jogador
                    MinRadius = game_logic:get_min_player_radius(FinalPlayers),

                    % Verificar se existe um número mínimo de Foods e Poisons
                    % MIN_FOODS = 6, MIN_POISONS = 8
                    % Garantir a existência de pelo menos uma Food com raio menor que o menor jogador
                    {FinalFoods, CreatedFoods} = game_logic:manage_world_foods(NewFoods, MinRadius),
                    {FinalPoisons, CreatedPoisons} = game_logic:manage_world_poisons(NewPoisons),

                    CreatedEntities = CreatedFoods ++ CreatedPoisons,
                    % Verificar se há alterações nos jogadores, Foods ou Poisons e enviar apenas as alterações
                    case {maps:size(UpdatedPlayers), RemovedIDs, CreatedEntities} of
                        {0, [], []} ->
                            ok;
                        _ ->
                            TimeStamp = erlang:system_time(millisecond),
                            % Enviamos apenas os jogadores que se mexeram (PlayersMoving)
                            % Enviar alterações/delta para todos os jogadores
                            send_changes_to_players(
                                FinalPlayers, UpdatedPlayers, CreatedEntities, RemovedIDs, TimeStamp
                            )
                    end,

                    loop(
                        FinalPlayers,
                        FinalFoods,
                        FinalPoisons,
                        NewGameScores,
                        MatchmakerPid,
                        NewTimeLeft,
                        TimerRef
                    )
            end
    end.

process_movement(Players) ->
    maps:fold(
        fun(Pid, Player, PlayersAcc) ->
            % Calcular o movimento do jogador com base no input recebido
            FinalPlayer = game_logic:update_player(Player),
            % Atualizar mapa de jogadores
            maps:put(Pid, FinalPlayer, PlayersAcc)
        end,
        #{},
        Players
    ).

check_collisions(Players, Foods, Poisons) ->
    % Verificar colisões com Comida
    {UpdatedPlayers1, RemainingFoods, RemovedFoodIDs} = game_logic:check_food_collisions(
        Players, Foods
    ),

    % Verificar colisões com Veneno
    {UpdatedPlayers2, RemainingPoisons, RemovedPoisonIDs} = game_logic:check_poison_collisions(
        UpdatedPlayers1, Poisons
    ),

    % Verificar colisões entre jogadores
    {FinalPlayers, Hunters} = game_logic:check_player_collisions(UpdatedPlayers2),

    {FinalPlayers, Hunters, RemainingFoods, RemainingPoisons, RemovedFoodIDs ++ RemovedPoisonIDs}.

% Verificar em que jogadores houve alterações
check_updated_players(OldPlayers, NewPlayers) ->
    maps:filter(
        fun(Pid, NewPlayer) ->
            OldPlayer = maps:get(Pid, OldPlayers),
            (NewPlayer#player.x /= OldPlayer#player.x) orelse
                (NewPlayer#player.y /= OldPlayer#player.y) orelse
                (NewPlayer#player.angle /= OldPlayer#player.angle) orelse
                (NewPlayer#player.radius /= OldPlayer#player.radius)
        end,
        NewPlayers
    ).

% Enviar as alterações (delta) para os jogadores
send_changes_to_players(Players, UpdatedPlayers, NewEntities, RemovedIDs, TimeStamp) ->
    Delta = game_serialization:serialize_changes(UpdatedPlayers, NewEntities, RemovedIDs),
    Header = io_lib:format("DELTA,TS,~p;", [TimeStamp]),
    maps:foreach(
        fun(Pid, _P) ->
            Pid ! {delta_update, list_to_binary([Header, Delta, ";\n"])}
        end,
        Players
    ).

end_game(Players, GameScores, MatchmakerPid) ->
    % Ordenar os jogadores por pontuação
    SortedScores = lists:reverse(lists:keysort(2, maps:to_list(GameScores))),

    case SortedScores of
        % Verificar se houve empate
        [{User1, Score1}, {User2, Score2} | _] when Score1 =:= Score2 ->
            io:format("GAME_SESSION: Game finished with a draw between ~p and ~p~n", [User1, User2]),
            notify_players_game_over(Players, SortedScores, draw);
        [{Winner, WinnerScore} | _] ->
            io:format("GAME_SESSION: Game finished. Winner: ~p with score ~p~n", [
                Winner, WinnerScore
            ]),

            % Atualizar pontuações
            ScoresToUpdate = maps:to_list(GameScores),
            scores_manager:update_scores(ScoresToUpdate),

            % Notificar jogadores do resultado final
            notify_players_game_over(Players, SortedScores, Winner);
        [] ->
            ok
    end,
    io:format("GAME_SESSION: Game finished. Notifying matchmaker...~n"),
    MatchmakerPid ! game_finished,
    ok.

notify_players_game_over(Players, SortedScores, Result) ->
    % Criar texto com resultados para enviar aos jogadores
    ScoreboardStr = string:join(
        [io_lib:format("~s:~p", [U, S]) || {U, S} <- SortedScores],
        ";"
    ),

    % Enviar a mensagem de game over para cada jogador,
    % incluindo o resultado (vencedor ou empate) e a pontuação final
    maps:foreach(
        fun(Pid, _) ->
            Pid ! {game_over, Result, ScoreboardStr}
        end,
        Players
    ).
