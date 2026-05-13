-module(game_logic).
-export([
    create_player/3,
    create_food/0,
    create_poison/0,
    calculate_spawn_positions/2,
    update_player/1,
    check_food_collisions/2,
    check_poison_collisions/2,
    check_player_collisions/3,
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

% Extrair {X, Y, Radius} de qualquer entidade (food ou poison).
entity_geometry(#food{x = X, y = Y, radius = R}) -> {X, Y, R};
entity_geometry(#poison{x = X, y = Y, radius = R}) -> {X, Y, R}.

% Extrai a massa de qualquer entidade
entity_mass(#food{mass = M}) -> M;
entity_mass(#poison{mass = M}) -> M.

% Extrair o Id de qualquer entidade
entity_id(#food{id = Id}) -> Id;
entity_id(#poison{id = Id}) -> Id.

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
player_eats_player(Eater, Eaten, Players, Foods, Poison) ->
    StolenMass = Eaten#player.mass * 0.25,
    NewEater = player_add_mass(Eater, StolenMass),
    NewEaten = player_add_mass(Eaten, -StolenMass),
    {NewEater, respawn_player(NewEaten, Players, Foods, Poison)}.

% Jogador faz respawn em posição aleatória do mapa
% de maneira a evitar dar spawn em cima de outros jogadores/Foods/Poisons
respawn_player(P, Players, Foods, Poisons) ->
    Radius = round(P#player.radius),
    find_safe_position(P, Players, Foods, Poisons, Radius, ?RESPAWN_MAX_ATTEMPTS).

% Procurar coordenadas "seguras" para dar respawn ao jogador
% Esgotámos as tentativas — nascer no centro como fallback.
find_safe_position(P, _, _, _, _, 0) ->
    P#player{
        x = ?MAP_WIDTH / 2.0,
        y = ?MAP_HEIGHT / 2.0,
        vx = 0.0,
        vy = 0.0,
        angularVelocity = 0.0
    };
find_safe_position(P, Players, Foods, Poisons, Radius, Attempts) ->
    % Gerar posição candidata dentro dos limites do mapa
    RInt = max(1, round(Radius)),
    % Valores candidatos
    CandX = float(RInt + rand:uniform(?MAP_WIDTH - 2 * RInt)),
    CandY = float(RInt + rand:uniform(?MAP_HEIGHT - 2 * RInt)),

    case is_position_safe(CandX, CandY, Radius, Players, Foods, Poisons, P#player.id) of
        true ->
            P#player{
                x = CandX,
                y = CandY,
                vx = 0.0,
                vy = 0.0,
                angularVelocity = 0.0
            };
        false ->
            find_safe_position(P, Players, Foods, Poisons, Radius, Attempts - 1)
    end.

is_position_safe(X, Y, Radius, Players, Foods, Poisons, SelfId) ->
    not overlaps_any_player(X, Y, Radius, maps:values(Players), SelfId) andalso
        not overlaps_any_entity(X, Y, Radius, maps:values(Foods)) andalso
        not overlaps_any_entity(X, Y, Radius, maps:values(Poisons)).

overlaps_any_player(_, _, _, [], _) ->
    false;
overlaps_any_player(X, Y, Radius, [P | Rest], SelfId) ->
    case P#player.id =:= SelfId of
        true ->
            overlaps_any_player(X, Y, Radius, Rest, SelfId);
        false ->
            %% Raio de segurança alargado: evitar nascer perto de outro jogador.
            %% Passamos SafeRadius em vez de R para alargar a zona de segurança.
            SafeRadius = Radius * ?RESPAWN_SAFETY_RADIUS_FACTOR,
            case check_overlap({X, Y}, {P#player.x, P#player.y}, SafeRadius, P#player.radius) of
                true -> true;
                false -> overlaps_any_player(X, Y, Radius, Rest, SelfId)
            end
    end.

% Verificar se jogador nasce em cima de alguma entidade (Foods/Poisons)
overlaps_any_entity(_, _, _, []) ->
    false;
overlaps_any_entity(X, Y, Radius, [Entity | Rest]) ->
    {EntityX, EntityY, EntityRadius} = entity_geometry(Entity),
    case check_overlap({X, Y}, {EntityX, EntityY}, Radius, EntityRadius) of
        true -> true;
        false -> overlaps_any_entity(X, Y, Radius, Rest)
    end.

% Unifica check_food_collisions e check_poison_collisions.
% Verificar colisões de todos os jogadores com Foods ou Poisons
% CollisionFun: função que decide se há colisão dado (PlayerPos, EntityPos, PlayerR, EntityR)
% MassFun: função que calcula a variação de massa dada a entidade
check_entity_collisions(Players, Entities, CollisionFun, MassFun) ->
    maps:fold(
        fun(Pid, Player, {AccPlayers, AccEntities, AccRemovedIDs}) ->
            % Para cada jogador, verificamos as entidades (Foods ou Poisons) restantes
            {NewP, NewEntities, RemovedIDs} =
                check_single_player_entities(Player, AccEntities, CollisionFun, MassFun),
            {
                maps:put(Pid, NewP, AccPlayers),
                NewEntities,
                RemovedIDs ++ AccRemovedIDs
            }
        end,
        {Players, Entities, []},
        Players
    ).

% Verificar colisões com Entidades, atualizar massa do jogador,
% remover Entidades do mapa e devolver lista de IDs removidos
check_single_player_entities(P, Entities, CollisionFun, MassFun) ->
    PlayerPos = {P#player.x, P#player.y},
    maps:fold(
        fun(Id, Entity, {NewP, NewEntities, RemovedIDs}) ->
            {EntityX, EntityY, EntityR} = entity_geometry(Entity),
            case CollisionFun(PlayerPos, {EntityX, EntityY}, NewP#player.radius, EntityR) of
                true ->
                    MassDelta = MassFun(Entity),
                    {
                        player_add_mass(NewP, MassDelta),
                        maps:remove(Id, NewEntities),
                        [Id | RemovedIDs]
                    };
                false ->
                    {NewP, NewEntities, RemovedIDs}
            end
        end,
        {P, Entities, []},
        Entities
    ).

% Verificar colisões de todos os jogadores com Foods
check_food_collisions(Players, Foods) ->
    check_entity_collisions(
        Players,
        Foods,
        % food é capturado quando completamente contido
        fun check_fully_contains/4,
        % ganha a massa do food
        fun entity_mass/1
    ).

% Verificar colisões de todos os jogadores com Poisons
check_poison_collisions(Players, Poisons) ->
    check_entity_collisions(
        Players,
        Poisons,
        % poison actua com qualquer sobreposição
        fun check_overlap/4,
        % perde a massa do poison
        fun(Entity) -> -entity_mass(Entity) end
    ).

% Verificar colisões entre jogadores
check_player_collisions(Players, Foods, Poisons) ->
    PlayersList = maps:to_list(Players),
    {UpdatedList, Hunters} = collide_players(PlayersList, [], [], Players, Foods, Poisons),
    {maps:from_list(UpdatedList), Hunters}.

% Função auxiliar para verificar colisões entre jogadores de forma recursiva
% (comparar cada jogador com os seguintes na lista para evitar comparações desnecessárias)
% Performance: O(N(N-1)/2) vs O(N^2) se comparássemos todos contra todos

% Casos base: lista vazia ou um jogador restante (não há colisões)
collide_players([], Acc, Hunters, _, _, _) ->
    {Acc, Hunters};
collide_players([LastPlayer], Acc, Hunters, _, _, _) ->
    {[LastPlayer | Acc], Hunters};
% Caso recursivo: comparar o primeiro jogador com todos os outros
collide_players([{Pid, P1} | Rest], Acc, Hunters, Players, Foods, Poisons) ->
    % Verificar colisões entre P1 e os jogadores restantes
    {NewP1, NewRest, NewHunters} = check_one_vs_others(
        P1, Rest, [], Hunters, Players, Foods, Poisons
    ),
    % Verificar colsiões entre os jogadores restantes
    collide_players(NewRest, [{Pid, NewP1} | Acc], NewHunters, Players, Foods, Poisons).

% Verificar colisões entre um jogador e uma lista de outros jogadores
check_one_vs_others(P1, [], Acc, Hunters, _, _, _) ->
    {P1, lists:reverse(Acc), Hunters};
check_one_vs_others(P1, [{Pid2, P2} | Rest], Acc, Hunters, Players, Foods, Poisons) ->
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
            {NewP1, NewP2} = player_eats_player(P1, P2, Players, Foods, Poisons),
            check_one_vs_others(
                NewP1,
                Rest,
                [{Pid2, NewP2} | Acc],
                [P1#player.username | Hunters],
                Players,
                Foods,
                Poisons
            );
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
                    {NewP2, NewP1} = player_eats_player(P2, P1, Players, Foods, Poisons),
                    check_one_vs_others(
                        NewP1,
                        Rest,
                        [{Pid2, NewP2} | Acc],
                        [
                            P2#player.username | Hunters
                        ],
                        Players,
                        Foods,
                        Poisons
                    );
                % Sem colisão
                _ ->
                    check_one_vs_others(
                        P1, Rest, [{Pid2, P2} | Acc], Hunters, Players, Foods, Poisons
                    )
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
    {NewFoods, CreatedEntities} = fill_entities(Foods, ?MIN_FOODS, [], fun() ->
        {create_food(), food}
    end),

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
    fill_entities(Poisons, ?MIN_POISONS, [], fun() -> {create_poison(), poison} end).

% Preencher o mapa com Foods ou Poisons até atingir o número mínimo e
% criar uma lista de entidades criadas para enviar aos clientes
fill_entities(Entities, Min, CreatedEntities, CreateFun) ->
    case maps:size(Entities) < Min of
        true ->
            {E, Type} = CreateFun(),
            fill_entities(
                maps:put(entity_id(E), E, Entities),
                Min,
                [{E, Type} | CreatedEntities],
                CreateFun
            );
        false ->
            {Entities, CreatedEntities}
    end.
