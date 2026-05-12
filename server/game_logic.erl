-module(game_logic).
-export([
    create_player/3,
    create_food/0,
    create_poison/0,
    calculate_spawn_positions/2,
    update_player/1,
    check_food_collisions/2,
    check_poison_collisions/2,
    check_player_collisions/1,
    get_min_player_radius/1,
    manage_world_foods/2,
    manage_world_poisons/1
]).
-include("game_entities.hrl").
-include("game_constants.hrl").

% --------------------------------------------------------------------------------------------
% ENTIDADES
% --------------------------------------------------------------------------------------------
% Criar jogador com atributos iniciais
create_player(Id, {X, Y}, Username) ->
    #player{id = Id, username = Username, x = X, y = Y}.

% Criar comida massa entre 5 e 10
create_food() ->
    Mass = float(4 + rand:uniform(6)),
    Radius = math:sqrt(Mass / math:pi()) * 3.0,

    #food{
        id = erlang:unique_integer([monotonic, positive]),
        x = float(rand:uniform(?MAP_WIDTH - 50) + 25),
        y = float(rand:uniform(?MAP_HEIGHT - 50) + 25),
        mass = Mass,
        radius = Radius
    }.

% Criar veneno com massa entre 20 e 30
create_poison() ->
    % rand:uniform(11) dá 1 a 11 -> Massa 20 a 30
    Mass = float(19 + rand:uniform(11)),
    Radius = math:sqrt(Mass / math:pi()) * 3.0,

    #poison{
        id = erlang:unique_integer([monotonic, positive]),
        x = float(rand:uniform(?MAP_WIDTH - 50) + 25),
        y = float(rand:uniform(?MAP_HEIGHT - 50) + 25),
        mass = Mass,
        radius = Radius
    }.

% Define posições iniciais para 3 ou 4 jogadores,
% garantindo que estão suficientemente distantes do centro e entre si.
calculate_spawn_positions(4, _) ->
    [
        {?MAP_WIDTH / 4, ?MAP_HEIGHT / 4},
        {3 * ?MAP_WIDTH / 4, ?MAP_HEIGHT / 4},
        {?MAP_WIDTH / 4, 3 * ?MAP_HEIGHT / 4},
        {3 * ?MAP_WIDTH / 4, 3 * ?MAP_HEIGHT / 4}
    ];
calculate_spawn_positions(3, Radius) ->
    Cx = ?MAP_WIDTH / 2,
    Cy = ?MAP_HEIGHT / 2,
    % Ângulos: 0, 120 e 240 graus
    Angles = [0, (2 * math:pi()) / 3, (4 * math:pi()) / 3],
    [
        {float(round(Cx + Radius * math:cos(A))), float(round(Cy + Radius * math:sin(A)))}
     || A <- Angles
    ].

% --------------------------------------------------------------------------------------------
% MOVIMENTOS DO JOGADOR
% --------------------------------------------------------------------------------------------
% Calcular nova posição e ângulo do jogador e aplicar restrições de limites do mapa
update_player(P) ->
    % Calcular a aceleração angular
    AccAngular =
        if
            P#player.moving_left -> -P#player.torque / P#player.mass;
            P#player.moving_right -> P#player.torque / P#player.mass;
            true -> 0.0
        end,

    % Atualizar velocidade angular
    NewAV = P#player.angularVelocity + AccAngular,

    % Limitar a velocidade de rotação
    FinalAV = lists:max([
        lists:min([NewAV, P#player.maxAngularVelocity]), -P#player.maxAngularVelocity
    ]),

    % Atualizar ângulo com base na velocidade angular e Normalizar (0 a 2*pi)
    NewAngle = fmod(P#player.angle + FinalAV, math:pi() * 2),

    AccLinear =
        if
            P#player.moving_up -> P#player.force / P#player.mass;
            true -> 0.0
        end,

    NewVX = P#player.vx + (math:cos(NewAngle) * AccLinear),
    NewVY = P#player.vy + (math:sin(NewAngle) * AccLinear),

    % Limitar a velocidade máxima linear
    Speed = math:sqrt(NewVX * NewVX + NewVY * NewVY),
    {LimitedVX, LimitedVY} =
        if
            Speed > P#player.maxVelocity ->
                Ratio = P#player.maxVelocity / Speed,
                {NewVX * Ratio, NewVY * Ratio};
            true ->
                {NewVX, NewVY}
        end,

    % Atualizar posição com base na velocidade
    NewX = P#player.x + LimitedVX,
    NewY = P#player.y + LimitedVY,

    % Aplicamos os limites (Se bater, a velocidade naquele eixo morre)
    {FinalX, FinalVX} = check_boundaries(NewX, LimitedVX, P#player.radius, ?MAP_WIDTH),
    {FinalY, FinalVY} = check_boundaries(NewY, LimitedVY, P#player.radius, ?MAP_HEIGHT),

    % Atualizar jogador
    P#player{
        x = FinalX,
        y = FinalY,
        vx = FinalVX,
        vy = FinalVY,
        angle = NewAngle,
        angularVelocity = FinalAV
    }.

% Verificar se o jogador ultrapassa os limites do mapa
check_boundaries(Pos, Vel, Radius, Max) ->
    if
        Pos < Radius -> {Radius, 0.0};
        Pos > (Max - Radius) -> {Max - Radius, 0.0};
        true -> {Pos, Vel}
    end.

% Função auxiliar para normalizar o ângulo
fmod(X, Y) ->
    Res = X - Y * trunc(X / Y),
    if
        Res < 0 -> Res + Y;
        true -> Res
    end.
% --------------------------------------------------------------------------------------------
% COLISÕES
% --------------------------------------------------------------------------------------------
% Calcular distância entre dois pontos
calculate_distance({X1, Y1}, {X2, Y2}) ->
    math:sqrt(math:pow(X2 - X1, 2) + math:pow(Y2 - Y1, 2)).

% Verificar se dois círculos (jogadores, Foods, Poisons) colidem
check_overlap({X1, Y1}, {X2, Y2}, Radius1, Radius2) ->
    Distance = calculate_distance({X1, Y1}, {X2, Y2}),
    Distance < (Radius1 + Radius2).

% Verificar se um círculo (jogador) contém completamente outro (Food, Poison)
check_fully_contains({X1, Y1}, {X2, Y2}, Radius1, Radius2) ->
    Distance = calculate_distance({X1, Y1}, {X2, Y2}),
    Distance + Radius2 < Radius1.

% Aumentar massa e recalcular raio (raio é proporcional à raiz quadrada da massa)
player_add_mass(P, Mass) ->
    NewMass = lists:max([P#player.minMass, P#player.mass + Mass]),
    NewRadius = math:sqrt(NewMass / math:pi()) * 3.0,
    % Atualizar jogador
    P#player{mass = NewMass, radius = NewRadius}.

% Jogador "come" outro jogador - rouba 25% da massa do outro jogador
player_eats_player(Eater, Eaten) ->
    StolenMass = Eaten#player.mass * 0.25,
    NewEater = player_add_mass(Eater, StolenMass),
    NewEaten = player_add_mass(Eaten, -StolenMass),
    {NewEater, respawn_player(NewEaten)}.

% Jogador faz respawn em posição aleatória do mapa
% Melhorar para evitar dar spawn em cima de outros jogadores/Foods/Poisons
respawn_player(P) ->
    Radius = round(P#player.radius),
    P#player{
        x = float(Radius + rand:uniform(?MAP_WIDTH - 2 * Radius)),
        y = float(Radius + rand:uniform(?MAP_HEIGHT - 2 * Radius)),
        vx = 0.0,
        vy = 0.0,
        angle = 0.0,
        moving_up = false,
        moving_left = false,
        moving_right = false
    }.

% Verificar colisões de todos os jogadores com Foods
check_food_collisions(Players, Foods) ->
    maps:fold(
        fun(Pid, Player, {AccPlayers, AccFoods, AccRemovedIDs}) ->
            % Para cada jogador, verificamos as Foods restantes
            {NewP, NewFoods, RemovedIDs} = check_single_player_food(Player, AccFoods),
            {
                maps:put(Pid, NewP, AccPlayers),
                NewFoods,
                RemovedIDs ++ AccRemovedIDs
            }
        end,
        {Players, Foods, []},
        Players
    ).

% Verificar colisões com Foods, atualizar massa do jogador, remover Foods do mapa e devolver lista de IDs removidos
check_single_player_food(P, Foods) ->
    maps:fold(
        fun(Id, Food, {NewP, NewFoods, RemovedIDs}) ->
            case
                check_fully_contains(
                    {P#player.x, P#player.y},
                    {Food#food.x, Food#food.y},
                    P#player.radius,
                    Food#food.radius
                )
            of
                true ->
                    {player_add_mass(NewP, Food#food.mass), maps:remove(Id, NewFoods), [
                        Id | RemovedIDs
                    ]};
                false ->
                    {NewP, NewFoods, RemovedIDs}
            end
        end,
        {P, Foods, []},
        Foods
    ).

% Verificar colisões de todos os jogadores com Poisons
check_poison_collisions(Players, Poisons) ->
    maps:fold(
        fun(Pid, Player, {AccPlayers, AccPoisons, AccRemovedIDs}) ->
            {NewP, NewPoisons, RemovedIDs} = check_single_player_poison(Player, AccPoisons),
            {
                maps:put(Pid, NewP, AccPlayers),
                NewPoisons,
                RemovedIDs ++ AccRemovedIDs
            }
        end,
        {Players, Poisons, []},
        Players
    ).

% Verificar colisões com Poisons, atualizar massa do jogador, remover Poisons do mapa e devolver lista de IDs removidos
check_single_player_poison(P, Poisons) ->
    maps:fold(
        fun(Id, Poison, {NewP, NewPoisons, RemovedIDs}) ->
            case
                check_overlap(
                    {P#player.x, P#player.y},
                    {Poison#poison.x, Poison#poison.y},
                    P#player.radius,
                    Poison#poison.radius
                )
            of
                true ->
                    {player_add_mass(NewP, -Poison#poison.mass), maps:remove(Id, NewPoisons), [
                        Id | RemovedIDs
                    ]};
                false ->
                    {NewP, NewPoisons, RemovedIDs}
            end
        end,
        {P, Poisons, []},
        Poisons
    ).

% Verificar colisões entre jogadores
check_player_collisions(Players) ->
    PlayersList = maps:to_list(Players),
    {UpdatedList, Hunters} = collide_players(PlayersList, [], []),
    {maps:from_list(UpdatedList), Hunters}.

% Função auxiliar para verificar colisões entre jogadores de forma recursiva
% (comparar cada jogador com os seguintes na lista para evitar comparações desnecessárias)
% Performance: O(N(N-1)/2) vs O(N^2) se comparássemos todos contra todos

% Casos base: lista vazia ou um jogador restante (não há colisões)
collide_players([], Acc, Hunters) ->
    {Acc, Hunters};
collide_players([LastPlayer], Acc, Hunters) ->
    {[LastPlayer | Acc], Hunters};
% Caso recursivo: comparar o primeiro jogador com todos os outros
collide_players([{Pid, P1} | Rest], Acc, Hunters) ->
    % Verificar colisões entre P1 e os jogadores restantes
    {NewP1, NewRest, NewHunters} = check_one_vs_others(P1, Rest, [], Hunters),
    % Verificar colsiões entre os jogadores restantes
    collide_players(NewRest, [{Pid, NewP1} | Acc], NewHunters).

% Verificar colisões entre um jogador e uma lista de outros jogadores
check_one_vs_others(P1, [], Acc, Hunters) ->
    {P1, lists:reverse(Acc), Hunters};
check_one_vs_others(P1, [{Pid2, P2} | Rest], Acc, Hunters) ->
    % Verificar se P1 come P2
    case
        check_fully_contains(
            {P1#player.x, P1#player.y},
            {P2#player.x, P2#player.y},
            P1#player.radius,
            P2#player.radius
        )
    of
        true when P1#player.mass > P2#player.mass ->
            {NewP1, NewP2} = player_eats_player(P1, P2),
            check_one_vs_others(NewP1, Rest, [{Pid2, NewP2} | Acc], [P1#player.username | Hunters]);
        % Verificar se P2 come P1
        _ ->
            case
                check_fully_contains(
                    {P2#player.x, P2#player.y},
                    {P1#player.x, P1#player.y},
                    P2#player.radius,
                    P1#player.radius
                )
            of
                true when P2#player.mass > P1#player.mass ->
                    {NewP2, NewP1} = player_eats_player(P2, P1),
                    check_one_vs_others(NewP1, Rest, [{Pid2, NewP2} | Acc], [
                        P2#player.username | Hunters
                    ]);
                % Sem colisão
                _ ->
                    check_one_vs_others(P1, Rest, [{Pid2, P2} | Acc], Hunters)
            end
    end.

% Obter o menor raio entre os jogadores
get_min_player_radius(Players) ->
    PlayersRadius = [P#player.radius || P <- maps:values(Players)],

    case PlayersRadius of
        [] -> 0;
        _ -> lists:min(PlayersRadius)
    end.

% Verificar se há Foods menores que o raio fornecido (menor jogador)
check_smaller_food(Foods, MinRadius) ->
    % Filtrar alimentos menores que o menor jogador
    SmallerFoods = maps:filter(fun(_, F) -> F#food.radius < MinRadius end, Foods),

    maps:size(SmallerFoods) > 0.

% Fazer a gestão de Foods no mundo
manage_world_foods(Foods, MinRadius) ->
    % Garantir número mínimo de foods
    {NewFoods, CreatedEntities} = fill_entities(Foods, ?MIN_FOODS, [], food),

    % Garantir que haja pelo menos um alimento menor que o menor jogador
    case check_smaller_food(NewFoods, MinRadius) of
        % Se já existe, manter o Foods atual
        true ->
            {NewFoods, CreatedEntities};
        % Se não existe, criar um novo com raio menor que o menor jogador
        false ->
            NewFood = create_food(),
            UpdatedFoods = maps:put(
                NewFood#food.id,
                NewFood#food{radius = MinRadius - 1.0, mass = math:pow(MinRadius - 1.0, 2)},
                NewFoods
            ),
            {UpdatedFoods, [{NewFood, food} | CreatedEntities]}
    end.

% Fazer a gestão de Poisons no mundo
manage_world_poisons(Poisons) ->
    % Garantir número mínimo de venenos
    fill_entities(Poisons, ?MIN_POISONS, [], poison).

% Preencher o mapa com Foods ou Poisons até atingir o número mínimo e
% criar uma lista de entidades criadas para enviar aos clientes
fill_entities(Entities, Min, CreatedEntities, Type) ->
    CurrentSize = maps:size(Entities),
    case CurrentSize < Min of
        true ->
            case Type of
                food ->
                    E = create_food(),
                    fill_entities(
                        maps:put(E#food.id, E, Entities), Min, [{E, food} | CreatedEntities], food
                    );
                poison ->
                    E = create_poison(),
                    fill_entities(
                        maps:put(E#poison.id, E, Entities),
                        Min,
                        [{E, poison} | CreatedEntities],
                        poison
                    )
            end;
        false ->
            {Entities, CreatedEntities}
    end.
