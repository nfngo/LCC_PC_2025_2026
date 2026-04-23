package state;

import processing.core.PApplet;
import model.GameWorld;
import network.ClientConnection;
import input.InputHandler;
import ui.*;

public class StateManager {

    private GameState state = GameState.LOGIN;

    private final LoginScreen login;
    private final MenuScreen menu;
    private final ScoreboardScreen scoreboard;

    private final GameWorld world;

    public StateManager(PApplet p, GameWorld world, ClientConnection conn) {
        this.world = world;

        login = new LoginScreen(p, this, conn);
        menu = new MenuScreen(p, this, conn);
        scoreboard = new ScoreboardScreen(p, this);
    }

    public void update() {

        switch(state) {
            case LOGIN -> login.update();
            case MENU -> menu.update();
            case GAME -> world.update();
            case SCOREBOARD -> scoreboard.update();
        }
    }

    public void draw() {

        switch(state) {
            case LOGIN -> login.draw();
            case MENU -> menu.draw();
            case GAME -> world.draw();
            case SCOREBOARD -> scoreboard.draw();
        }
    }

    public void handleKey(char key, int keyCode) {

        switch(state) {
            case LOGIN -> login.handleKey(key, keyCode);
            case MENU -> menu.handleKey(key, keyCode);
            case SCOREBOARD -> scoreboard.handleKey(key, keyCode);
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
}
