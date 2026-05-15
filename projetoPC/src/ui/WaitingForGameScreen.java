package ui;

import network.ClientConnection;
import network.ParseScore;
import processing.core.PApplet;
import state.GameState;
import state.StateManager;

import java.util.HashMap;
import java.util.Map;

import static network.MessageParser.parseScoreboard;

public class WaitingForGameScreen {
    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    private String message = ""; // feedback (erro/sucesso)
    private int playersWaiting = 0;

    private final Map<Integer, ParseScore> scores = new HashMap<>();

    public WaitingForGameScreen(PApplet p, StateManager manager,  ClientConnection conn) {
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
        p.text("WAITING ROOM", centerX, startY + 40);

        // Status/Mensagem
        p.textSize(24);
        p.text(message, centerX, startY + 100);

        // Cabeçalho da Tabela
        float tableTop = startY + 160;
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

        // Scores (Top 10)
        p.noStroke();
        p.textSize(18);
        p.textAlign(PApplet.CENTER, PApplet.CENTER);
        for (int i = 0; i < Math.min(scores.size(), 10); i++) {
            int rank = i + 1;
            ParseScore score = scores.get(rank);
            float y = tableTop + 25 + (i * 25);

            if (rank <= 3) {
                if (rank == 1) p.fill(212, 175, 55);
                else if (rank == 2) p.fill(192, 192, 192);
                else p.fill(205, 127, 50);
                p.circle(rankX, y, 18);
            }

            p.fill(0);
            p.text(rank, rankX, y);
            p.text(score.username(), centerX, y);
            p.text(score.score(), scoreX, y);
        }

        p.fill(0);
        p.textSize(20);
        p.text("PLAYERS: " + playersWaiting + "/4", centerX, startY + boxH - 55);

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
            leave();
        }
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

        parseScoreboard(payload, scores);
    }

    public void onGetScoreboardFail(String payload) {
        message = "";
        scores.clear();

        if(payload.equals("timeout")) {
            message = "Oops! Unable to load the scoreboard.";
        }
    }

    public void onWaitingOtherPlayers(String payload) {
        message = "Waiting for other players...";
        playersWaiting = Integer.parseInt(payload);
    }

    public void onGameStartingSoon(String payload) {
        message = "Game starting soon...";
        playersWaiting = Integer.parseInt(payload);
    }

    public void onActiveGamesFull() {
        message = "Game slots are full. Waiting for a match to finish...";
    }

}
