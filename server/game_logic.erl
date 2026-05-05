-module(game_logic).
-export([
    calculate_spawn_positions/2,
    update_player/1,
    check_food_collisions/2,
    check_poison_collisions/2,
    check_player_collisions/1
]).
-include("game_entities.hrl").
-include("game_constants.hrl").

% Define posições iniciais para 3 ou 4 jogadores,
% garantindo que estão suficientemente distantes do centro e entre si.
calculate_spawn_positions(4, Radius) ->
    [
        {?MAP_WIDTH div 4, ?MAP_HEIGHT div 4},
        {3 * ?MAP_WIDTH div 4, ?MAP_HEIGHT div 4},
        {?MAP_WIDTH div 4, 3 * ?MAP_HEIGHT div 4},
        {3 * ?MAP_WIDTH div 4, 3 * ?MAP_HEIGHT div 4}
    ];
calculate_spawn_positions(3, Radius) ->
    Cx = ?MAP_WIDTH / 2,
    Cy = ?MAP_HEIGHT / 2,
    % Ângulos: 0, 120 e 240 graus
    Angles = [0, (2 * math:pi()) / 3, (4 * math:pi()) / 3],
    [{round(Cx + Radius * math:cos(A)), round(Cy + Radius * math:sin(A))} || A <- Angles].

% --------------------------------------------------------------------------------------------
% MOVIMENTOS DO JOGADOR
% --------------------------------------------------------------------------------------------
% Acelerar
accelerate_forward(P) ->
    % Calcular nova velocidade com base na força aplicada
    NewVX = P#player.vx + math:cos(P#player.angle) * (P#player.force / P#player.mass),
    NewVY = P#player.vy + math:sin(P#player.angle) * (P#player.force / P#player.mass),

    % Calcular a velocidade atual (Teorema de Pitágoras)
    Speed = math:sqrt(NewVX * NewVX + NewVY * NewVY),

    % Se a velocidade atual exceder a velocidade máxima, normalizar para MaxVelocity
    {FVX, FVY} =
        if
            Speed > P#player.maxVelocity ->
                {(NewVX / Speed) * P#player.maxVelocity, (NewVY / Speed) * P#player.maxVelocity};
            true ->
                {NewVX, NewVY}
        end,
    P#player{vx = FVX, vy = FVY}.

% Virar/Rodar para a esquerda
turn_left(P) ->
    NewAV = lists:max([
        P#player.angularVelocity - (P#player.torque / P#player.mass), -P#player.maxAngularVelocity
    ]),
    P#player{angularVelocity = NewAV}.

% Virar/Rodar para a direita
turn_right(P) ->
    NewAV = lists:min([
        P#player.angularVelocity + (P#player.torque / P#player.mass), P#player.maxAngularVelocity
    ]),
    P#player{angularVelocity = NewAV}.

% Calcular nova posição e ângulo do jogador e aplicar restrições de limites do mapa
update_player(P) ->
    % Atualizar posição com base na velocidade
    NextX = P#player.x + P#player.vx,
    NextY = P#player.y + P#player.vy,

    % Atualizar ângulo com base na velocidade angular
    NextAngle = P#player.angle + P#player.angularVelocity,

    % Aplicamos os limites (Se bater, a velocidade naquele eixo morre)
    {FinalX, FinalVX} = check_boundaries(NextX, P#player.vx, P#player.radius, ?MAP_WIDTH),
    {FinalY, FinalVY} = check_boundaries(NextY, P#player.vy, P#player.radius, ?MAP_HEIGHT),

    % Atualizar jogador
    P#player{x = FinalX, y = FinalY, vx = FinalVX, vy = FinalVY, angle = NextAngle}.

% Verificar se o jogador ultrapassa os limites do mapa
check_boundaries(Pos, Vel, Radius, Max) ->
    if
        Pos < Radius -> {Radius, 0.0};
        Pos > (Max - Radius) -> {Max - Radius, 0.0};
        true -> {Pos, Vel}
    end.
% --------------------------------------------------------------------------------------------
% COLISÕES
% --------------------------------------------------------------------------------------------
% Calcular distância entre dois pontos
calculate_distance({X1, Y1}, {X2, Y2}) ->
    math:sqrt(math:pow(X2 - X1, 2) + math:pow(Y2 - Y1, 2)).

% Verificar se dois círculos (jogadores, comida, veneno) colidem
check_overlap({X1, Y1}, {X2, Y2}, Radius1, Radius2) ->
    Distance = calculate_distance({X1, Y1}, {X2, Y2}),
    Distance < (Radius1 + Radius2).

% Verificar se um círculo (jogador) contém completamente outro (comida, veneno)
check_fully_contains({X1, Y1}, {X2, Y2}, Radius1, Radius2) ->
    Distance = calculate_distance({X1, Y1}, {X2, Y2}),
    Distance + Radius2 < Radius1.

% Aumentar massa e recalcular raio (raio é proporcional à raiz quadrada da massa)
player_add_mass(P, Mass) ->
    NewMass = lists:max([P#player.minMass, P#player.mass + Mass]),
    NewRadius = math:sqrt(NewMass),
    % Atualizar jogador
    P#player{mass = NewMass, radius = NewRadius}.

% Jogador "come" outro jogador - rouba 25% da massa do outro jogador
player_eats_player(Eater, Eaten) ->
    StolenMass = Eaten#player.mass * 0.25,
    NewEater = player_add_mass(Eater, StolenMass),
    NewEaten = player_add_mass(Eaten, -StolenMass),
    {NewEater, respawn_player(NewEaten)}.

% Jogador faz respawn em posição aleatória do mapa
% Melhorar para evitar dar spawn em cima de outros jogadores/comida/veneno
respawn_player(P) ->
    P#player{
        x = P#player.radius + rand:uniform(?MAP_WIDTH - P#player.radius),
        y = P#player.radius + rand:uniform(?MAP_HEIGHT - P#player.radius),
        vx = 0.0,
        vy = 0.0,
        angle = 0.0,
        moving_up = false,
        moving_left = false,
        moving_right = false
    }.

% Verificar colisões com comida, atualizar massa do jogador e remover comida do mapa
check_food_collisions(P, Foods) ->
    maps:fold(
        fun(Id, Food, {NewP, NewFoods}) ->
            case
                check_fully_contains(
                    {P#player.x, P#player.y},
                    {Food#food.x, Food#food.y},
                    P#player.radius,
                    Food#food.radius
                )
            of
                true ->
                    {player_add_mass(NewP, Food#food.mass), maps:remove(Id, NewFoods)};
                false ->
                    {NewP, NewFoods}
            end
        end,
        {P, Foods},
        Foods
    ).

% Verificar colisões com veneno, atualizar massa do jogador e remover veneno do mapa
check_poison_collisions(P, Poisons) ->
    maps:fold(
        fun(Id, Poison, {NewP, NewPoisons}) ->
            case
                check_overlap(
                    {P#player.x, P#player.y},
                    {Poison#poison.x, Poison#poison.y},
                    P#player.radius,
                    Poison#poison.radius
                )
            of
                true ->
                    {player_add_mass(NewP, -Poison#poison.mass), maps:remove(Id, NewPoisons)};
                false ->
                    {NewP, NewPoisons}
            end
        end,
        {P, Poisons},
        Poisons
    ).

% Verificar colisões entre jogadores
check_player_collisions(Players) ->
    PlayersList = maps:to_list(Players),
    UpdatedList = collide_players(PlayersList, []),
    maps:from_list(UpdatedList).

% Função auxiliar para verificar colisões entre jogadores de forma recursiva
% (comparar cada jogador com os seguintes na lista para evitar comparações desnecessárias)
% Performance: O(N(N-1)/2) vs O(N^2) se comparássemos todos contra todos

% Casos base: lista vazia ou um jogador restante (não há colisões)
collide_players([], Acc) ->
    Acc;
collide_players([LastPlayer], Acc) ->
    [LastPlayer | Acc];
% Caso recursivo: comparar o primeiro jogador com todos os outros
collide_players([{Pid, P1} | Rest], Acc) ->
    % Verificar colisões entre P1 e os jogadores restantes
    {NewP1, NewRest} = check_one_vs_others(P1, Rest, []),
    % Verificar colsiões entre os jogadores restantes
    collide_players(NewRest, [{Pid, NewP1} | Acc]).

% Verificar colisões entre um jogador e uma lista de outros jogadores
check_one_vs_others(P1, [], Acc) ->
    {P1, lists:reverse(Acc)};
check_one_vs_others(P1, [{Pid2, P2} | Rest], Acc) ->
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
            check_one_vs_others(NewP1, Rest, [{Pid2, NewP2} | Acc]);
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
                    check_one_vs_others(NewP1, Rest, [{Pid2, NewP2} | Acc]);
                % Sem colisão
                _ ->
                    check_one_vs_others(P1, Rest, [{Pid2, P2} | Acc])
            end
    end.
