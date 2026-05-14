package ui;

import network.ClientConnection;
import processing.core.PApplet;
import state.GameState;
import state.StateManager;

import java.util.ArrayList;
import java.util.Collections;

public class WaitingForGameScreen {
    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    private String message = ""; // feedback (erro/sucesso)

    private final ArrayList<String> scores = new ArrayList<>();

    public WaitingForGameScreen(PApplet p, StateManager manager,  ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        p.fill(0);
        p.textSize(32);
        p.text("WAITING ROOM", 280, 100);

        p.textSize(16);
        for (int i = 0; i < scores.size(); i++) {
            p.text(scores.get(i), 300, 200 + i * 20);
        }

        if(!message.isEmpty()) {
            p.text(message, 300, 180);
        }
    }

    public void handleKey(char key, int keyCode) {
    }

    private void leave() {
        conn.send("LEAVE");
        manager.setState(GameState.MENU);
    }

    public void onPlaySuccess() {
        manager.setState(GameState.WAITING_FOR_GAME);
    }

    public void onGetScoreboardSuccess(String payload) {
        message = "";
        scores.clear();

        String[] parts = payload.split(",");
        Collections.addAll(scores, parts);
    }

    public void onGetScoreboardFail(String payload) {
        message = payload;
    }

    public void onWaitingOtherPlayers() {
        message = "Waiting for other players...";
    }

    public void onActiveGamesFull() {
        message = "All game slots are currently occupied. Waiting for a match to finish...";
    }

    public void onGameStart() {
        manager.setState(GameState.GAME);
    }
}
