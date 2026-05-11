-module(scores_manager).
-export([start/2, stop/0, register_user/1, delete_user/1, update_scores/1, get_scoreboard/1]).

start(Scores, ScoresFMPid) ->
    Pid = spawn(fun() -> loop(Scores, ScoresFMPid) end),
    register(?MODULE, Pid).

stop() ->
    ?MODULE ! stop.

register_user(Username) ->
    ?MODULE ! {register_user, Username}.

delete_user(Username) ->
    ?MODULE ! {delete_user, Username}.

update_scores(ScoresToUpdate) ->
    ?MODULE ! {update_scores, ScoresToUpdate}.

get_scoreboard(FromPid) ->
    % Criar uma referência única para este pedido,
    % para garantir que a resposta recebida é para este pedido específico
    % (se uma resposta chegar após o timeout, deve ser ignorada)
    Tag = make_ref(),
    ?MODULE ! {get_scoreboard, FromPid, Tag},
    receive
        {ok, Top10, Tag} -> {ok, Top10}
        % Timeout para evitar deadlock caso o scores_manager não responda
    after 2000 -> {error, timeout}
    end.

loop(Scores, ScoresFMPid) ->
    receive
        stop ->
            % Gravar o estado atual antes de parar o processo
            files_manager:save(ScoresFMPid, Scores),
            io:format("SCORES_MANAGER: final state saved. Shutting down...~n"),
            ok;
        {register_user, Username} ->
            io:format("SCORES_MANAGER: registering user ~p...~n", [Username]),
            % Adicionar um novo utilizador com pontuação inicial de 0 no momento do registo
            NewScores = maps:put(Username, 0, Scores),
            files_manager:save(ScoresFMPid, NewScores),
            loop(NewScores, ScoresFMPid);
        {delete_user, Username} ->
            io:format("SCORES_MANAGER: deleting user ~p...~n", [Username]),
            % Remover um utilizador do mapa de pontuações quando a sua conta for eliminada
            NewScores = maps:remove(Username, Scores),
            files_manager:save(ScoresFMPid, NewScores),
            loop(NewScores, ScoresFMPid);
        {update_scores, ScoresToUpdate} ->
            io:format("SCORES_MANAGER: updating scores...~n"),
            % Atualizar a pontuação dos utilizadores após o fim de um jogo
            NewScores = lists:foldl(
                fun({User, Points}, Acc) ->
                    CurrentScore = maps:get(User, Acc, 0),
                    maps:put(User, CurrentScore + Points, Acc)
                end,
                Scores,
                ScoresToUpdate
            ),

            files_manager:save(ScoresFMPid, NewScores),
            loop(NewScores, ScoresFMPid);
        {get_scoreboard, FromPid, Tag} ->
            io:format("SCORES_MANAGER: received request for scoreboard~n"),
            % Converter mapa para lista
            ScoresList = maps:to_list(Scores),
            % Ordenar por pontuação
            Sorted = lists:keysort(2, ScoresList),
            % Obter top 10
            Top10 = lists:sublist(lists:reverse(Sorted), 10),
            % Enviar o scoreboard
            FromPid ! {ok, Top10, Tag},
            loop(Scores, ScoresFMPid);
        _ ->
            loop(Scores, ScoresFMPid)
    end.
