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
            return new ServerMessage(ServerMessage.Type.GAME_OVER, msg);

        } else if (msg.startsWith("SCORE")) {
            return new ServerMessage(ServerMessage.Type.SCORE, msg);

        } else if (msg.startsWith("STATE")) {
            return new ServerMessage(ServerMessage.Type.STATE, msg.substring(6));

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

        for (String t : tokens) {

            String[] parts = t.split(",");

            switch (parts[0]) {

                // Identificação do jogador local
                case "ID":
                    selfId = Integer.parseInt(parts[1]);
                    break;

                // Player
                case "P":
                    int id = Integer.parseInt(parts[1]);

                    float x = Float.parseFloat(parts[2]);
                    float y = Float.parseFloat(parts[3]);
                    float r = Float.parseFloat(parts[4]);
                    float angle = Float.parseFloat(parts[5]);

                    Player player = playersMap.get(id);

                    if (player == null) {
                        player = new Player(p, id, x, y, r, false);
                        playersMap.put(id, player);
                    }

                    player.updateFromServer(x, y, r, angle);

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
                            Float.parseFloat(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3])));
                    break;

                // Poison
                case "X":
                    objects.add(new Poison(p,
                            Float.parseFloat(parts[1]),
                            Float.parseFloat(parts[2]),
                            Float.parseFloat(parts[3])));
                    break;
            }
        }
        return new ParseResult(selfPlayer, selfId);
    }
}