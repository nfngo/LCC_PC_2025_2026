import network.MessageParser;
import network.ServerMessage;
import processing.core.PApplet;
import input.InputHandler;
import network.ClientConnection;
import processing.core.PFont;
import state.GameState;
import state.StateManager;
import model.GameWorld;

public class Main extends PApplet {

    private InputHandler input;
    private ClientConnection connection;
    private StateManager stateManager;
    private PFont f;

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
        frameRate(60);

        input = new InputHandler();
        connection = new ClientConnection("127.0.0.1", 12345);
        GameWorld world = new GameWorld(this);
        stateManager = new StateManager(this, world, connection);

        f = createFont("Arial",16,true);
    }

    public void draw() {
        background(240);
        textFont(f);

        if (connection.isConnected()) {

            // Apenas envia se algo mudou (tecla premida ou solta)
            if (input.hasChanged()) {
                connection.sendInput(input);
            }

            // Processar eventos
            String eventMsg;
            while ((eventMsg = connection.pollEvent()) != null) {

                ServerMessage sm = MessageParser.parseMessage(eventMsg);

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

                    case PLAY_OK:
                        stateManager.getWaiting().onPlaySuccess();
                        break;

                    case WAITING_OTHER_PLAYERS:
                        stateManager.getWaiting().onWaitingOtherPlayers();
                        break;

                    case ACTIVE_GAMES_FULL:
                        stateManager.getWaiting().onActiveGamesFull();
                        break;

                    case GAME_OVER:
                        stateManager.getWorld().onGameOver(sm.getPayload());
                        // Implementar mensagem no Menu ou criar novo screen após jogo terminar
                        // stateManager.getMenu().showGameOver("Game Over!");
                        stateManager.setState(GameState.MENU);
                        break;

                    case SCOREBOARD_OK:
                        if(stateManager.getState() == GameState.MENU) {
                            stateManager.getScoreboard().onGetScoreboardSuccess(sm.getPayload());
                            break;
                        }
                        if(stateManager.getState() == GameState.WAITING_FOR_GAME) {
                            stateManager.getWaiting().onGetScoreboardSuccess(sm.getPayload());
                            break;
                        }

                    case SCOREBOARD_FAIL:
                        if(stateManager.getState() == GameState.MENU) {
                            stateManager.getScoreboard().onGetScoreboardFail(sm.getPayload());
                            break;
                        }
                        if(stateManager.getState() == GameState.WAITING_FOR_GAME) {
                            stateManager.getWaiting().onGetScoreboardFail(sm.getPayload());
                            break;
                        }

                    case ERROR:
                        stateManager.getLogin().onError(sm.getPayload());
                        break;

                    default:
                        println("Unknown message: " + eventMsg);
                }
            }

/*            if (connection.hasWorldQueueOverflow()) {
                connection.clearWorldQueueOverflow();
                connection.send("REQUEST_STATE");
            }*/

            String stateMsg;
/*            int processedWorldMessages = 0;
            int maxWorldMessagesPerFrame = 50;*/

            while((stateMsg = connection.pollState()) != null) {
                ServerMessage sm = MessageParser.parseMessage(stateMsg);

                if(sm.getType() == ServerMessage.Type.STATE) {
                    stateManager.getWorld().applyState(sm.getPayload());
                    stateManager.setState(GameState.GAME);
                }

                if(sm.getType() == ServerMessage.Type.DELTA) {
                    stateManager.getWorld().applyDelta(sm.getPayload());
                }

/*                processedWorldMessages++;*/
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
