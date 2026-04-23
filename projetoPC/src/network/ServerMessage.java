package network;

public class ServerMessage {

    public enum Type {
        LOGIN_OK,
        LOGIN_FAIL,
        REGISTER_OK,
        REGISTER_FAIL,
        LOGOUT_OK,
        DELETE_OK,
        DELETE_FAIL,
        GAME_OVER,
        ERROR,
        SCORE,
        STATE,
        UNKNOWN
    }

    private final Type type;
    private final String payload;

    public ServerMessage(Type type, String payload) {
        this.type = type;
        this.payload = payload;
    }

    public Type getType() {
        return type;
    }

    public String getPayload() {
        return payload;
    }
}