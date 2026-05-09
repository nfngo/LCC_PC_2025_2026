-module(game_session).
-export([start_game/2, init/2]).
-include("game_entities.hrl").
-include("game_constants.hrl").

start_game(PlayerPids, MatchmakerPid) ->
    spawn(fun() -> init(PlayerPids, MatchmakerPid) end).

init(PlayerPids, MatchmakerPid) ->
    % Inicializar avatares dos jogadores
    Players = create_players(PlayerPids),
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
            Header = io_lib:format("STATE,ID,~p,TS,~p;", [P#player.id, TimeStamp]),
            Pid ! {game_started, self(), list_to_binary([Header, InitialState, ";\n"])}
        end,
        Players
    ),

    % Enviar a mensagem 'tick' para este processo (self()) a cada 50ms
    TimerRef = timer:send_interval(?TICK_INTERVAL, self(), tick),

    loop(Players, Foods, Poisons, MatchmakerPid, ?GAME_TIME, TimerRef).

% Criar jogadores e atribui posições iniciais no mapa
create_players(PlayerPids) ->
    Positions = game_logic:calculate_spawn_positions(length(PlayerPids), 200),

    Ids = lists:seq(1, length(PlayerPids)),

    maps:from_list(
        [
            {Pid, game_logic:create_player(Id, Pos)}
         || {Pid, Id, Pos} <- lists:zip3(PlayerPids, Ids, Positions)
        ]
    ).

loop(Players, Foods, Poisons, MatchmakerPid, TimeLeft, TimerRef) ->
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
                    loop(NewPlayers, Foods, Poisons, MatchmakerPid, TimeLeft, TimerRef);
                error ->
                    loop(Players, Foods, Poisons, MatchmakerPid, TimeLeft, TimerRef)
            end;
        tick ->
            % Calcular quanto tempo falta
            NewTimeLeft = TimeLeft - ?TICK_INTERVAL,

            if
                % Se o tempo acabou, terminar o jogo
                NewTimeLeft =< 0 ->
                    timer:cancel(TimerRef),
                    end_game(Players, MatchmakerPid);
                true ->
                    % Processar o movimento de cada jogador e obter os jogadores que se moveram
                    {NewPlayers, PlayersMoving} = process_movement(Players),

                    % Verificar colisões
                    {FinalPlayers, NewFoods, NewPoisons, RemovedIDs} = check_collisions(
                        NewPlayers, Foods, Poisons
                    ),

                    % Obter raio do menor jogador
                    MinRadius = game_logic:get_min_player_radius(Players),

                    % Verificar se existe um número mínimo de Foods e Poisons
                    % MIN_FOODS = 6, MIN_POISONS = 8
                    % Garantir a existência de pelo menos uma Food com raio menor que o menor jogador
                    {FinalFoods, CreatedFoods} = game_logic:manage_world_foods(NewFoods, MinRadius),
                    {FinalPoisons, CreatedPoisons} = game_logic:manage_world_poisons(NewPoisons),

                    CreatedEntities = CreatedFoods ++ CreatedPoisons,
                    % Verificar se há alterações nos jogadores, Foods ou Poisons e enviar apenas as alterações
                    case {maps:size(PlayersMoving), RemovedIDs, CreatedEntities} of
                        {0, [], []} ->
                            ok;
                        _ ->
                            TimeStamp = erlang:system_time(millisecond),
                            % Enviamos apenas os jogadores que se mexeram (PlayersMoving)
                            % Enviar alterações/delta para todos os jogadores
                            send_changes_to_players(
                                PlayersMoving, CreatedEntities, RemovedIDs, TimeStamp
                            )
                    end,

                    loop(
                        FinalPlayers, FinalFoods, FinalPoisons, MatchmakerPid, NewTimeLeft, TimerRef
                    )
            end
    end.

process_movement(Players) ->
    maps:fold(
        fun(Pid, Player, {AccAll, AccMoving}) ->
            % Calcular o movimento do jogador com base no input recebido
            UpdatedPlayer = game_logic:apply_player_input(Player),

            % Verificar se está em movimento
            IsMoving = game_logic:is_player_moving(UpdatedPlayer),

            NewAccMoving =
                if
                    IsMoving -> maps:put(Pid, UpdatedPlayer, AccMoving);
                    true -> AccMoving
                end,

            {maps:put(Pid, UpdatedPlayer, AccAll), NewAccMoving}
        end,
        {#{}, #{}},
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
    FinalPlayers = game_logic:check_player_collisions(UpdatedPlayers2),

    {FinalPlayers, RemainingFoods, RemainingPoisons, RemovedFoodIDs ++ RemovedPoisonIDs}.

% Enviar as alterações (delta) para os jogadores
send_changes_to_players(Players, NewEntities, RemovedIDs, TimeStamp) ->
    Delta = game_serialization:serialize_changes(Players, NewEntities, RemovedIDs),
    maps:foreach(
        fun(Pid, P) ->
            Header = io_lib:format("DELTA,ID,~p,TS,~p;", [P#player.id, TimeStamp]),
            Pid ! {delta_update, list_to_binary([Header, Delta, ";\n"])}
        end,
        Players
    ).

end_game(Players, MatchmakerPid) ->
    % A implementar:
    % Calcular e enviar resultados
    Score = 100,
    maps:foreach(
        fun(Pid, _) ->
            Pid ! {game_over, Score}
        end,
        Players
    ),
    io:format("GAME_SESSION: Game finished. Notifying matchmaker...~n"),
    MatchmakerPid ! game_finished,
    ok.
