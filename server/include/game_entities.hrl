%% File: game_entities.hrl

%%-----------------------------------------------------------
%% Data Type: player
%% onde:
%%    id: Identificador único do jogador (default - undefined)
%%    x: Posição atual do jogador no eixo dos X (default - undefined)
%%    y: Posição atual do jogador no eixo dos Y (default - undefined)
%%    angle: Ângulo atual do jogador (em radianos) (default - 0.0)
%%    mass: Massa atual do jogador (default - 200.0)
%%    minMass: Massa mínima de um jogador (default - 50.0)
%%    radius: Raio atual do jogador (default - sqrt(mass))
%%    vx: Velocidade atual do jogador na direcção de X (default - 0.0)
%%    vy: Velocidade atual do jogador na direcção de Y (default - 0.0)
%%    angularVelocity: Velocidade angular atual do jogador (default is 0.0)
%%    maxAngularVelocity: Velocidade angular máxima permitida a um jogador (default - 0.05)
%%    maxVelocity: Velocidade linear máxima permitida a um jogador (default - 3.0)
%%    force: Força atua aplicada ao jogador (default - 4.0)
%%    torque: Torque atual aplicado ao jogador (default - 0.2)
%%    moving_up: Boolean a indicar se o jogador está atualmente a mexer-se para cima (default - false)
%%    moving_left: Boolean a indicar se o jogador está atualmente a mexer-se para a esquerda (default - false)
%%    moving_right: Boolean a indicar se o jogador está atualmente a mexer-se para a direita (default - false)
%%------------------------------------------------------------
-record(player, {
    id,
    x,
    y,
    angle = 0.0,
    mass = 200.0,
    minMass = 50.0,
    radius = math:sqrt(200.0),
    vx = 0.0,
    vy = 0.0,
    angularVelocity = 0.0,
    maxAngularVelocity = 0.05,
    maxVelocity = 3.0,
    force = 4.0,
    torque = 0.2,
    moving_up = false,
    moving_left = false,
    moving_right = false
}).

%%-----------------------------------------------------------
%% Data types: food e poison
%% onde:
%%    id: Identificador único da entidade (default - undefined
%%    x: Coordenada X da entidade (default - 0.0)
%%    y: Coordenada Y da entidade (default - 0.0)
%%    radius: Raio da entidade (default - undefined)
%%    mass: Massa da entidade (default - undefined)
%%------------------------------------------------------------
-record(food, {id, x = 0.0, y = 0.0, radius, mass}).
-record(poison, {id, x = 0.0, y = 0.0, radius, mass}).
