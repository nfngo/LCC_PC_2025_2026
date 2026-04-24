-module(game_session).
-export([start_game/2, init/2]).
-include("game_entities.hrl").
-include("game_constants.hrl").

start_game(PlayerPids, MatchmakerPid) ->
    spawn(fun() -> init(PlayerPids, MatchmakerPid) end).

init(PlayerPids, MatchmakerPid) ->
    % Inicializa avatares dos jogadores
    Players = create_players(PlayerPids),
    io:format("GAME_SESSION: players:\n ~p~n", [Players]),

    % Inicializa Foods com IDs de 1 a 12
    Foods = maps:from_list([{I, create_food(I)} || I <- lists:seq(1, 12)]),
    io:format("GAME_SESSION: foods:\n ~p~n", [Foods]),

    % Inicializa Poisons com IDs de 100 a 115 (para evitar colisão com IDs de Foods)
    Poisons = maps:from_list([{I, create_poison(I)} || I <- lists:seq(100, 115)]),
    io:format("GAME_SESSION: poisons:\n ~p~n", [Poisons]),

    % Notificar jogadores
    [Pid ! {game_started, self()} || Pid <- PlayerPids],

    loop(Players, Foods, Poisons, MatchmakerPid).

% Cria jogadores e atribui posições iniciais no mapa
create_players(PlayerPids) ->
    Positions = game_logic:calculate_spawn_positions(length(PlayerPids), 200),

    maps:from_list(
        [
            {Pid, #player{id = Pid, x = X, y = Y}}
         || {Pid, {X, Y}} <- lists:zip(PlayerPids, Positions)
        ]
    ).

% Cria comida com raio entre 5 e 25 e massa entre 10 e 40
create_food(Id) ->
    #food{
        id = Id,
        x = rand:uniform(?MAP_WIDTH),
        y = rand:uniform(?MAP_HEIGHT),
        radius = 4 + rand:uniform(21),
        mass = 9 + rand:uniform(31)
    }.

% Cria veneno com raio entre 8 e 35 e massa entre 10 e 35
create_poison(Id) ->
    #poison{
        id = Id,
        x = rand:uniform(?MAP_WIDTH),
        y = rand:uniform(?MAP_HEIGHT),
        radius = 7 + rand:uniform(28),
        mass = 9 + rand:uniform(26)
    }.

loop(Players, Foods, Poisons, MatchmakerPid) ->
    receive
        {input, PlayerId, {Left, Up, Right}} ->
            Player = maps:get(PlayerId, Players),
            % Cria uma versão atualizada apenas com os novos estados
            NewPlayer = Player#player{
                moving_up = Up,
                moving_left = Left,
                moving_right = Right
            },
            % Guarda no mapa e continua o loop
            NewPlayers = maps:put(PlayerId, NewPlayer, Players),
            loop(NewPlayers, Foods, Poisons, MatchmakerPid);
        tick ->
            ok
    after 120000 ->
        % A implementar:
        % Calcular e enviar resultados
        Score = 100,
        maps:foreach(
            fun(Pid, _Player) ->
                Pid ! {game_over, Score}
            end,
            Players
        ),
        io:format("GAME_SESSION: Game finished. Notifying matchmaker...~n"),
        MatchmakerPid ! game_finished,
        ok
    end.
