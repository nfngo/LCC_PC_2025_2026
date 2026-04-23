-module(files_manager).
-export([start/1, save/2, load/1, stop/1]).

% Cria um novo processo de gestão de ficheiros para um ficheiro específico
start(FileName) ->
    spawn(fun() -> loop(FileName) end).

stop(Pid) ->
    Pid ! stop.

% Grava dados de forma assíncrona (não bloqueia o processo que chama)
save(Pid, Data) ->
    Pid ! {save, Data}.

% Lê dados de forma síncrona (necessário no arranque do servidor,
% para carregar os utilizadores e o scoreboard existentes)
load(Pid) ->
    Pid ! {load, self()},
    receive
        {data, Data} -> Data
    end.

loop(FileName) ->
    receive
        stop ->
            io:format("FILES_MANAGER: Shutting down...~n"),
            ok;
        {save, Data} ->
            case file:write_file(FileName, term_to_binary(Data)) of
                ok ->
                    io:format("FILES_MANAGER: ~p saved sucessfully~n", [FileName]),
                    loop(FileName);
                {error, Reason} ->
                    io:format("FILES_MANAGER: Error saving ~p: ~p~n", [FileName, Reason]),
                    loop(FileName)
            end;
        {load, From} ->
            % Lê e converte o binário de volta para termo Erlang
            case file:read_file(FileName) of
                {ok, Bin} ->
                    Data = binary_to_term(Bin),
                    io:format("FILES_MANAGER: ~p loaded successfully~n", [FileName]);
                {error, enoent} ->
                    io:format("FILES_MANAGER: ~p not found~n", [FileName]),
                    Data = #{};
                {error, Reason} ->
                    io:format("FILES_MANAGER: Error loading ~p: ~p~n", [FileName, Reason]),
                    Data = #{}
            end,
            From ! {data, Data},
            loop(FileName)
    end.
