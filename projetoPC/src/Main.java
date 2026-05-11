import network.MessageParser;
import network.ServerMessage;
import processing.core.PApplet;
import input.InputHandler;
import network.ClientConnection;
import state.GameState;
import state.StateManager;
import model.GameWorld;

public class Main extends PApplet {

    private InputHandler input;
    private ClientConnection connection;
    private StateManager stateManager;

    public static void main(String[] args) {
        PApplet.main("Main");
    }

    //  Serve apenas para definir propriedades do sketch, como:
    //  - tamanho da janela
    //  - render (2D, 3D)
    public void settings() {
        size(1280, 720);
    }

    //  - inicializar variáveis
    //  - criar objetos
    //  - definir estilos iniciais
    public void setup() {
        input = new InputHandler();
        connection = new ClientConnection("127.0.0.1", 12345);
        GameWorld world = new GameWorld(this);
        stateManager = new StateManager(this, world, connection);
    }

    public void draw() {
        background(240);

        if (connection.isConnected()) {

            // Apenas envia se algo mudou (tecla premida ou solta)
            if (input.hasChanged()) {
                connection.sendInput(input);
            }

            // Processar eventos
            String eventMsg;
            while ((eventMsg = connection.poolEvent()) != null) {

                ServerMessage sm = MessageParser.parseMessage(eventMsg);

                // LOG
                println("SERVER: " + eventMsg);

                switch (sm.getType()) {

                    case REGISTER_OK:
                        stateManager.getLogin().onRegisterSuccess();
                        break;

                    case REGISTER_FAIL:
                        stateManager.getLogin().onRegisterFail(sm.getPayload());
                        break;

                    case LOGIN_OK:
                        stateManager.getLogin().onLoginSuccess();
                        break;

                    case LOGIN_FAIL:
                        stateManager.getLogin().onLoginFail(sm.getPayload());
                        break;

                    case LOGOUT_OK:
                        stateManager.getLogin().onLogoutSuccess();
                        break;

                    case DELETE_OK:
                        stateManager.getLogin().onDeleteSuccess();
                        break;

                    case DELETE_FAIL:
                        stateManager.getLogin().onDeleteFail(sm.getPayload());
                        break;

                    case GAME_OVER:
                        stateManager.getWorld().onGameOver(sm.getPayload());
                        // Implementar mensagem no Menu ou criar novo screen após jogo terminar
                        // stateManager.getMenu().showGameOver("Game Over!");
                        stateManager.setState(GameState.MENU);
                        break;

                    case SCOREBOARD_OK:
                        stateManager.getScoreboard().updateScores(sm.getPayload());
                        stateManager.setState(GameState.SCOREBOARD);
                        break;

                    case SCOREBOARD_FAIL:
                        // Implementar
                        //stateManager.getScoreboard().onUpdateScoresFail(sm.getPayload());
                        break;

                    case ERROR:
                        stateManager.getLogin().onError(sm.getPayload());
                        break;

                    default:
                        println("Unknown message: " + eventMsg);
                }
            }

            String stateMsg;
            while((stateMsg = connection.poolState()) != null) {
                System.out.println("SERVER: " + stateMsg);
                ServerMessage sm = MessageParser.parseMessage(stateMsg);

                if(sm.getType() == ServerMessage.Type.STATE) {
                    stateManager.getWorld().applyState(sm.getPayload());
                }

                if(sm.getType() == ServerMessage.Type.DELTA) {
                    stateManager.getWorld().applyDelta(sm.getPayload());
                }
            }

            stateManager.update();
            stateManager.draw();

        } else {
            fill(0);
            text("Disconnected from server", 100, 100);
        }
    }

    public void keyPressed() {
        input.keyPressed(key, keyCode);
        stateManager.handleKey(key, keyCode);
    }

    public void keyReleased() {
        input.keyReleased(key, keyCode);
    }
}
