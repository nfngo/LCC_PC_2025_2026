-module(game_serialization).
-export([serialize_world/3, serialize_changes/3]).
-include("game_entities.hrl").

% Serialização das alterações no mundo (delta)
serialize_changes(Players, NewEntities, RemovedIDs) ->
    UpdatedPlayersStr = serialize_players(maps:values(Players)),

    % Só adiciona NEW e DEL se houver alterações
    NewEntitiesStr = serialize_created_entities(NewEntities),
    % No caso de remoção de entidades (Foods e Poisons), apenas é necessário o ID,
    % uma vez que estão todos guardados na mesma estrutura de dados no cliente
    RemovedIDsStr =
        case RemovedIDs of
            [] -> "";
            _ -> "DEL," ++ string:join([integer_to_list(ID) || ID <- RemovedIDs], ",")
        end,

    string:join([UpdatedPlayersStr, NewEntitiesStr, RemovedIDsStr], ";").

% Serialização do estado completo do mundo
serialize_world(Players, Foods, Poisons) ->
    PlayersStr = serialize_players(maps:values(Players)),
    FoodsStr = serialize_foods(maps:values(Foods)),
    PoisonsStr = serialize_poisons(maps:values(Poisons)),
    % Criar string final, após filtrar strings vazias da lista
    string:join(lists:filter(fun(S) -> S /= "" end, [PlayersStr, FoodsStr, PoisonsStr]), ";").

% Serialização de jogadores
serialize_players(Players) ->
    string:join(
        [
            io_lib:format("P,~p,~.2f,~.2f,~.2f,~.2f", [
                P#player.id, P#player.x, P#player.y, P#player.radius, P#player.angle
            ])
         || P <- Players
        ],
        ";"
    ).

% Serialização de Foods
serialize_foods(Foods) ->
    string:join(
        [
            io_lib:format("F,~p,~.2f,~.2f,~.2f,~.2f", [
                F#food.id, F#food.x, F#food.y, F#food.radius, F#food.mass
            ])
         || F <- Foods
        ],
        ";"
    ).

% Serialização de Poisons
serialize_poisons(Poisons) ->
    string:join(
        [
            io_lib:format("X,~p,~.2f,~.2f,~.2f,~.2f", [
                P#poison.id, P#poison.x, P#poison.y, P#poison.radius, P#poison.mass
            ])
         || P <- Poisons
        ],
        ";"
    ).

% Serialização de entidadas criadas (Foods e Poisons) para envio de mensagem Delta
serialize_created_entities([]) ->
    "";
serialize_created_entities(Entities) ->
    string:join([serialize_created_entity(E) || E <- Entities], ";").

serialize_created_entity({Entity, food}) ->
    io_lib:format("NEW,F,~p,~.2f,~.2f,~.2f,~.2f", [
        Entity#food.id, Entity#food.x, Entity#food.y, Entity#food.radius, Entity#food.mass
    ]);
serialize_created_entity({Entity, poison}) ->
    io_lib:format("NEW,X,~p,~.2f,~.2f,~.2f,~.2f", [
        Entity#poison.id, Entity#poison.x, Entity#poison.y, Entity#poison.radius, Entity#poison.mass
    ]).
