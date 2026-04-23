package ui;

import processing.core.PApplet;
import state.*;
import network.ClientConnection;

import java.util.ArrayList;

public class ScoreboardScreen {

    private final PApplet p;
    private final StateManager manager;

    private ArrayList<String> scores = new ArrayList<>();

    public ScoreboardScreen(PApplet p, StateManager manager) {
        this.p = p;
        this.manager = manager;
    }

    public void update() {}

    public void draw() {
        p.fill(0);
        p.textSize(32);
        p.text("SCOREBOARD", 280, 100);

        p.textSize(16);
        for (int i = 0; i < scores.size(); i++) {
            p.text(scores.get(i), 300, 200 + i * 20);
        }

        p.text("Press M to return", 280, 500);
    }

    public void handleKey(char key, int keyCode) {
        if (key == 'm' || key == 'M') {
            manager.setState(GameState.MENU);
        }
    }

    public void updateScores(String payload) {
        scores.clear();

        String[] parts = payload.split(",");
        for (int i = 1; i < parts.length; i++) {
            scores.add(parts[i]);
        }
    }
}
