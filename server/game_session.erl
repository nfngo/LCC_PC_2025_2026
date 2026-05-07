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

    % Notificar jogadores
    [Pid ! {game_started, self()} || Pid <- PlayerPids],

    % Enviar a mensagem 'tick' para este processo (self()) a cada 50ms
    timer:send_interval(?TICK_INTERVAL, self(), tick),

    loop(Players, Foods, Poisons, MatchmakerPid, ?GAME_TIME).

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

loop(Players, Foods, Poisons, MatchmakerPid, TimeLeft) ->
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
                    loop(NewPlayers, Foods, Poisons, MatchmakerPid, TimeLeft);
                error ->
                    loop(Players, Foods, Poisons, MatchmakerPid, TimeLeft)
            end;
        tick ->
            % Calcular quanto tempo falta
            NewTimeLeft = TimeLeft - ?TICK_INTERVAL,

            if
                % Se o tempo acabou, terminar o jogo
                NewTimeLeft =< 0 ->
                    end_game(Players, MatchmakerPid);
                true ->
                    % Processar o movimento de cada jogador
                    MovedPlayers = process_movement(Players),

                    % Verificar colisões
                    {FinalPlayers, NewFoods, NewPoisons} = check_collisions(
                        MovedPlayers, Foods, Poisons
                    ),

                    % Obter raio do menor jogador
                    MinRadius = game_logic:get_min_player_radius(Players),

                    % Verificar se existe um número mínimo de Foods e Poisons
                    % MIN_FOODS = 6, MIN_POISONS = 8
                    % Garantir a existência de pelo menos uma Food com raio menor que o menor jogador
                    FinalFoods = game_logic:manage_world_foods(NewFoods, MinRadius),
                    FinalPoisons = game_logic:manage_world_poisons(NewPoisons),

                    % C. Enviar novo estado para todos os jogadores
                    % broadcast_state(FinalPlayers, FinalFoods, FinalPoisons),

                    loop(MovedPlayers, FinalFoods, FinalPoisons, MatchmakerPid, NewTimeLeft)
            end
    end.

process_movement(Players) ->
    maps:map(
        fun(_, P) ->
            % Aplicar alterações baseadas no input recebido do jogador
            P1 =
                if
                    P#player.moving_up -> game_logic:accelerate_forward(P);
                    true -> P
                end,
            P2 =
                if
                    P#player.moving_left -> game_logic:turn_left(P1);
                    true -> P1
                end,
            P3 =
                if
                    P#player.moving_right -> game_logic:turn_right(P2);
                    true -> P2
                end,

            % Mover o objeto
            game_logic:update_player(P3)
        end,
        Players
    ).

check_collisions(Players, Foods, Poisons) ->
    % Verificar colisões com Comida
    {UpdatedPlayers1, RemainingFoods} = game_logic:check_food_collisions(Players, Foods),

    % Verificar colisões com Veneno
    {UpdatedPlayers2, RemainingPoisons} = game_logic:check_poison_collisions(
        UpdatedPlayers1, Poisons
    ),

    % Verificar colisões entre jogadores
    {FinalPlayers} = game_logic:check_player_collisions(UpdatedPlayers2),

    {FinalPlayers, RemainingFoods, RemainingPoisons}.

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
