package state;

import processing.core.PApplet;
import model.GameWorld;
import network.ClientConnection;
import ui.*;

public class StateManager {

    private GameState state = GameState.LOGIN;

    private final LoginScreen login;
    private final MenuScreen menu;
    private final ScoreboardScreen scoreboard;
    private final WaitingForGameScreen waiting;
    private final GameOverScreen gameOver;

    private final GameWorld world;

    public StateManager(PApplet p, GameWorld world, ClientConnection conn) {
        this.world = world;

        login = new LoginScreen(p, this, conn);
        menu = new MenuScreen(p, this, conn);
        scoreboard = new ScoreboardScreen(p, this);
        waiting = new WaitingForGameScreen(p, this, conn);
        gameOver = new GameOverScreen(p, this, conn);
    }

    public void update() {

        switch(state) {
            case LOGIN -> login.update();
            case MENU -> menu.update();
            case GAME -> world.update();
            case SCOREBOARD -> scoreboard.update();
            case WAITING_FOR_GAME -> waiting.update();
            case GAME_OVER -> gameOver.update();
        }
    }

    public void draw() {

        switch(state) {
            case LOGIN -> login.draw();
            case MENU -> menu.draw();
            case GAME -> world.draw();
            case SCOREBOARD -> scoreboard.draw();
            case WAITING_FOR_GAME -> waiting.draw();
            case GAME_OVER -> gameOver.draw();
        }
    }

    public void handleKey(char key, int keyCode) {

        switch(state) {
            case LOGIN -> login.handleKey(key, keyCode);
            case MENU -> menu.handleKey(key, keyCode);
            case SCOREBOARD -> scoreboard.handleKey(key, keyCode);
            case WAITING_FOR_GAME -> waiting.handleKey(key, keyCode);
            case GAME_OVER -> gameOver.handleKey(key, keyCode);
        }
    }

    public void setState(GameState newState) {
        this.state = newState;
    }

    public GameState getState() {
        return state;
    }

    public ScoreboardScreen getScoreboard() {
        return scoreboard;
    }

    public LoginScreen getLogin() {
        return login;
    }

    public GameWorld getWorld() {
        return world;
    }

    public MenuScreen getMenu() {
        return menu;
    }

    public WaitingForGameScreen getWaiting() {
        return waiting;
    }

    public GameOverScreen getGameOver() {
        return gameOver;
    }
}
