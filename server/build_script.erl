-module(build_script).
-export([build/0]).

build() ->
    Modules = [game_logic, game_session, matchmaker, login_manager, server],
    lists:foreach(
        fun(Mod) ->
            case Mod of
                game_session ->
                    Res = compile:file(Mod, [{i, "include"}]);
                game_logic ->
                    Res = compile:file(Mod, [{i, "include"}]);
                _ ->
                    Res = compile:file(Mod)
            end,
            case Res of
                {ok, M} ->
                    io:format("OK: ~p compiled!~n", [M]);
                error ->
                    io:format("!ERROR! on file: ~p~n", [Mod])
            end
        end,
        Modules
    ).
