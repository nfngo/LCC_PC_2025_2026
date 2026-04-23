package ui;

import processing.core.PApplet;
import state.*;
import network.ClientConnection;

public class MenuScreen {

    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    private String message = ""; // feedback (erro/sucesso)

    public MenuScreen(PApplet p, StateManager manager, ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        p.fill(0);
        p.textSize(32);
        p.text("MENU", 340, 100);

        p.textSize(18);
        p.text("1 - Play", 300, 200);
        p.text("2 - Scoreboard", 300, 240);
        p.text("3 - Logout", 300, 280);
    }

    public void handleKey(char key, int keyCode) {

        if (key == '1') {
            conn.send("PLAY");
            manager.setState(GameState.GAME);

        } else if (key == '2') {
            conn.send("SCORE");
            manager.setState(GameState.SCOREBOARD);

        } else if (key == '3') {
            conn.send("LOGOUT");

        }
    }

    // Implementar métodos de feedback do servidor
    // onPlaySuccess, onScoreSuccess

}