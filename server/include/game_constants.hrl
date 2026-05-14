%% File: game_constants.hrl

% Dimensões do mapa
-define(MAP_WIDTH, 1280).
-define(MAP_HEIGHT, 720).
% Taxa de atualização (33ms para 30 FPS)
-define(TICK_INTERVAL, 33).
% Duração do jogo em milissegundos (2 minutos)
-define(GAME_TIME, 120000).
% Números inicial, mínimo e máximo de Foods e Poisons no mapa
-define(STARTING_FOODS, 12).
-define(MIN_FOODS, 6).
-define(MAX_FOODS, 18).
-define(STARTING_POISONS, 15).
-define(MIN_POISONS, 8).
-define(MAX_POISONS, 22).
% Fator para cálculo de distância de segurança no respawn de jogador
-define(RESPAWN_SAFETY_RADIUS_FACTOR, 5.0).
% Número máximo de tentativas de respawn de jogador
-define(RESPAWN_MAX_ATTEMPTS, 50).
