package network;

import processing.core.PApplet;
import entity.*;

import java.util.*;

public class MessageParser {

    // Parse genérico (tipo de mensagem)
    public static ServerMessage parseMessage(String msg) {

        if (msg == null || msg.isBlank()) {
            return new ServerMessage(ServerMessage.Type.UNKNOWN, "");
        }

        String command;
        String payload = "";

        int comma = msg.indexOf(',');

        if (comma == -1) {
            command = msg;
        } else {
            command = msg.substring(0, comma);
            payload = msg.substring(comma + 1);
        }

        try {
            ServerMessage.Type type = ServerMessage.Type.valueOf(command);

            if (type == ServerMessage.Type.ERROR) {
                payload = msg;
            }

            return new ServerMessage(type, payload);

        } catch (IllegalArgumentException e) {
            return new ServerMessage(ServerMessage.Type.UNKNOWN, msg);
        }
    }

    // Parse estado do jogo
    public static ParseResult parseGameState(
            PApplet p,
            String payload,
            Map<Integer, Player> playersMap,
            Map<Integer, Avatar> objects
    ) {

        playersMap.clear();
        objects.clear();
        String[] tokens = payload.split(";");

        int selfId = -1;
        Player selfPlayer = null;
        long timestamp = 0L;

        for (String t : tokens) {
            String[] parts = t.split(",");
            String type = parts[0];

            switch (type) {
                // Timestamp
                case "TS":
                    timestamp = Long.parseLong(parts[1]);
                    break;

                // Identificação do jogador local
                case "ID":
                    selfId = Integer.parseInt(parts[1]);
                    break;

                // Criar jogadores
                case "P":
                    int id = Integer.parseInt(parts[1]);

                    float x = Float.parseFloat(parts[2]);
                    float y = Float.parseFloat(parts[3]);
                    float r = Float.parseFloat(parts[4]);
                    float angle = Float.parseFloat(parts[5]);

                    Player player = playersMap.get(id);

                    if (player == null) {
                        player = new Player(p, id, x, y, r, angle, timestamp, false);
                        playersMap.put(id, player);
                    }

                    player.updateFromServer(x, y, r, angle, timestamp);

                    // definir se é o próprio
                    if (id == selfId) {
                        player.setSelf(true);
                        selfPlayer = player;
                    } else {
                        player.setSelf(false);
                    }
                    break;
                // Food
                case "F":
                    int foodId = Integer.parseInt(parts[1]);

                    objects.put(foodId, new Food(p,
                            foodId,
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Poison
                case "X":
                    int poisonId = Integer.parseInt(parts[1]);

                    objects.put(poisonId, new Poison(p,
                            poisonId,
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
            }
        }
        return new ParseResult(selfPlayer, selfId);
    }

    public static int parseDelta(PApplet p,
                                  String payload,
                                  Map<Integer, Player> playersMap,
                                  Map<Integer, Avatar> objects) {

        String[] tokens = payload.split(";");
        long timestamp = 0L;
        int score = 0;

        for (String t : tokens) {
            String[] parts = t.split(",");
            String type = parts[0];

            switch (type) {
                // Timestamp
                case "TS":
                    timestamp = Long.parseLong(parts[1]);
                    break;
                // Atualização de jogador
                case "P":
                    int id = Integer.parseInt(parts[1]);
                    float x = Float.parseFloat(parts[2]);
                    float y = Float.parseFloat(parts[3]);
                    float r = Float.parseFloat(parts[4]);
                    float angle = Float.parseFloat(parts[5]);

                    Player player = playersMap.get(id);
                    if (player != null) {
                        player.updateFromServer(x, y, r, angle, timestamp);
                    }

                    break;
                // Food
                case "F":
                    int foodId = Integer.parseInt(parts[1]);

                    objects.put(foodId, new Food(p,
                            foodId,
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Poison
                case "X":
                    int poisonId = Integer.parseInt(parts[1]);

                    objects.put(poisonId, new Poison(p,
                            poisonId,
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Remover Foods e Poisons através do ID
                case "DEL":
                    Set<Integer> idsToRemove = new HashSet<>();
                    for (int i = 1; i < parts.length; i++) {
                        idsToRemove.add(Integer.parseInt(parts[i]));
                    }
                    // Remover lista de objetos
                    objects.keySet().removeAll(idsToRemove);
                    break;
                // Remover jogadores através do ID
                case "DEL_P":
                    int playerId = Integer.parseInt(parts[1]);
                    playersMap.remove(playerId);
                    break;
                case "SCORE":
                    score = Integer.parseInt(parts[1]);
                    break;
            }
        }
        return score;
    }

    public static void parseScoreboard(String payload, Map<Integer, ParseScore> scores) {
        String[] parts = payload.split(",");
        for(int i = 0; i < parts.length; i++) {
            String[] scoreParts = parts[i].split(":");
            scores.put(i+1, new ParseScore(scoreParts[0], Integer.parseInt(scoreParts[1])));
        }
    }

    public static String parseGameOver(String payload, Map<Integer, ParseScore> scores) {
        String[] parts = payload.split(",");
        for(int i = 1; i < parts.length; i++) {
            String[] scoreParts = parts[i].split(":");
            scores.put(i, new ParseScore(scoreParts[0], Integer.parseInt(scoreParts[1])));
        }
        return parts[0];
    }
}