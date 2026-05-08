-module(build_script).
-export([build/0]).

build() ->
    Modules = [game_serialization, game_logic, game_session, matchmaker, login_manager, server],
    WithInclude = [game_session, game_logic, game_serialization],

    lists:foreach(
        fun(Module) ->
            Options =
                case lists:member(Module, WithInclude) of
                    true -> [{i, "include"}];
                    false -> []
                end,

            case compile:file(Module, Options) of
                {ok, M} -> io:format("OK: ~p compiled!~n", [M]);
                _ -> io:format("!ERROR! on file: ~p~n", [Module])
            end
        end,
        Modules
    ).
