-module(game_logic).
-export([calculate_spawn_positions/2]).
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
