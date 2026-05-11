package network;

import processing.core.PApplet;
import entity.*;

import java.util.*;

public class MessageParser {

    // Parse genérico (tipo de mensagem)
    public static ServerMessage parseMessage(String msg) {

        if (msg == null || msg.isEmpty()) {
            return new ServerMessage(ServerMessage.Type.UNKNOWN, "");
        }

        if (msg.startsWith("LOGIN_OK")) {
            return new ServerMessage(ServerMessage.Type.LOGIN_OK, "");

        } else if (msg.startsWith("LOGIN_FAIL")) {
            return new ServerMessage(ServerMessage.Type.LOGIN_FAIL, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("REGISTER_OK")) {
            return new ServerMessage(ServerMessage.Type.REGISTER_OK, "");

        } else if (msg.startsWith("REGISTER_FAIL")) {
            return new ServerMessage(ServerMessage.Type.REGISTER_FAIL, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("LOGOUT_OK")) {
            return new ServerMessage(ServerMessage.Type.LOGOUT_OK, "");

        } else if (msg.startsWith("DELETE_OK")) {
            return new ServerMessage(ServerMessage.Type.DELETE_OK, "");

        } else if (msg.startsWith("DELETE_FAIL")) {
            return new ServerMessage(ServerMessage.Type.DELETE_FAIL, msg.substring(msg.indexOf( ",") + 1));

        } else if (msg.startsWith("GAME_OVER")) {
            return new ServerMessage(ServerMessage.Type.GAME_OVER, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("SCOREBOARD_OK")) {
            return new ServerMessage(ServerMessage.Type.SCOREBOARD_OK, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("SCOREBOARD_FAIL")) {
            return new ServerMessage(ServerMessage.Type.SCOREBOARD_FAIL, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("STATE")) {
            return new ServerMessage(ServerMessage.Type.STATE, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("DELTA")) {
            return new ServerMessage(ServerMessage.Type.DELTA, msg.substring(msg.indexOf(",") + 1));

        } else if (msg.startsWith("ERROR")) {
            return new ServerMessage(ServerMessage.Type.ERROR, msg);

        } else {
            return new ServerMessage(ServerMessage.Type.UNKNOWN, msg);
        }
    }

    // Parse estado do jogo
    public static ParseResult parseGameState(
            PApplet p,
            String payload,
            Map<Integer, Player> playersMap,
            List<Avatar> objects
    ) {

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
                        player = new Player(p, id, x, y, r, timestamp, false);
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
                    objects.add(new Food(p,
                            Integer.parseInt(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Poison
                case "X":
                    objects.add(new Poison(p,
                            Integer.parseInt(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
            }
        }
        return new ParseResult(selfPlayer, selfId);
    }

    public static void parseDelta(PApplet p,
                                          String payload,
                                          Map<Integer, Player> playersMap,
                                          List<Avatar> objects) {

        String[] tokens = payload.split(";");
        long timestamp = 0L;

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
                    objects.add(new Food(p,
                            Integer.parseInt(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Poison
                case "X":
                    objects.add(new Poison(p,
                            Integer.parseInt(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3]),
                            Float.parseFloat(parts[4]),
                            timestamp));
                    break;
                // Remover Foods e Poisons através do ID
                case "DEL":
                    for (int i = 1; i < parts.length; i++) {
                        int idToRemove = Integer.parseInt(parts[i]);
                        // Remover lista de objetos
                        objects.removeIf(obj -> obj.getId() == idToRemove);
                    }
                    break;

            }
        }
    }
}