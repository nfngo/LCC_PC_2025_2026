package ui;

import network.ClientConnection;
import network.ParseScore;
import processing.core.PApplet;
import state.GameState;
import state.StateManager;

import java.util.HashMap;
import java.util.Map;

import static network.MessageParser.parseGameOver;

public class GameOverScreen {

    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    private final Map<Integer, ParseScore> scores = new HashMap<>();
    private String message = ""; // feedback (erro/sucesso)

    public GameOverScreen(PApplet p, StateManager manager,  ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        float boxW = 600;
        float boxH = 500;
        float startX = (p.width - boxW) / 2f;
        float startY = (p.height - boxH) / 2f;
        float centerX = p.width / 2f;

        // Caixa Principal
        p.fill(240);
        p.stroke(0);
        p.strokeWeight(4);
        p.rect(startX, startY, boxW, boxH);

        // Título
        p.noStroke();
        p.fill(0);
        p.textSize(42);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("GAME OVER", centerX, startY + 40);

        // Vencedor
        p.textSize(28);
        p.textAlign(PApplet.CENTER, PApplet.CENTER);
        p.text(message, centerX, startY + 125);

        // Cabeçalho da Tabela
        float tableTop = startY + 200;
        float rankX = centerX - 150;
        float scoreX = centerX + 150;

        p.textSize(16);
        p.fill(100);
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("RANK", rankX, tableTop);
        p.text("PLAYER", centerX, tableTop);
        p.text("SCORE", scoreX, tableTop);

        p.stroke(0);
        p.strokeWeight(2);
        p.line(startX + 80, tableTop + 5, startX + boxW - 80, tableTop + 5);

        // Scores
        p.noStroke();
        p.fill(0);
        p.textSize(18);
        p.textAlign(PApplet.CENTER, PApplet.CENTER);
        for (int i = 0; i < scores.size(); i++) {
            ParseScore score = scores.get(i + 1);
            float y = tableTop + 30 + (i * 35);

            if (i+1 == 1) {
                p.circle(rankX, y, 24);
                p.fill(255);
            }
            p.text(i + 1, rankX, y);
            p.fill(0);
            p.text(score.username(), centerX, y);
            p.text(score.score(), scoreX, y);
        }

        // Rodapé
        p.stroke(230);
        p.strokeWeight(1);
        p.line(startX + 60, startY + boxH - 35, startX + boxW - 60, startY + boxH - 35);

        p.noStroke();
        p.fill(50);
        p.textSize(16);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("[M] RETURN TO MAIN MENU", centerX, startY + boxH - 25);
    }

    public void handleKey(char key, int keyCode) {
        if (key == 'm' || key == 'M') {
            manager.setState(GameState.MENU);
        } else if(key == 's' || key == 'S') {
            getScoreboard();
        }
    }

    private void getScoreboard() {
        conn.send("SCOREBOARD");
    }

    public void onGameOverSuccess(String payload) {
        message = "";
        scores.clear();

        String winner = parseGameOver(payload, scores);
        if(winner.equals("draw")) {
            message = "IT'S A DRAW!";
        } else {
            message = "WINNER: " + winner;
        }
        manager.setState(GameState.GAME_OVER);
    }

}
