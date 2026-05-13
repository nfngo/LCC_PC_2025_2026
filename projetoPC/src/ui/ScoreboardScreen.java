package ui;

import network.ParseScore;
import processing.core.PApplet;
import state.*;

import java.util.HashMap;
import java.util.Map;

import static network.MessageParser.parseScoreboard;

public class ScoreboardScreen {

    private final PApplet p;
    private final StateManager manager;

    private final Map<Integer, ParseScore> scores = new HashMap<>();
    private String message;

    public ScoreboardScreen(PApplet p, StateManager manager) {
        this.p = p;
        this.manager = manager;
    }

    public void update() {}

    public void draw() {
        float startingX = ((float) p.width - 600)/2; // 340
        float startingY = ((float) p.height - 500)/2; // 110
        // finalX = 340 + 600 = 940
        float finalX = startingX + 600;
        // finalY = 110 + 500 = 610
        float finalY = startingY + 500;

        float centerX = (float) p.width / 2;

        // Caixa do menu
        p.fill(240);
        p.stroke(0);
        p.strokeWeight(4);
        p.rect(startingX, startingY, 600, 500);

        // Título
        // Cor: preto
        p.fill(0);
        p.textSize(40);
        // Alinhamento: centro, acima da posição onde começa
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("SCOREBOARD", centerX, startingY + 100);

        p.textSize(18);
        p.text("TOP 10 SCORES", centerX, startingY + 130);

        p.textAlign(PApplet.LEFT, PApplet.BOTTOM);
        p.text("RANK", startingX + 100, startingY + 160);
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("PLAYER", (float) p.width / 2, startingY + 160);
        p.textAlign(PApplet.RIGHT, PApplet.BOTTOM);
        p.text("SCORE", finalX - 100, startingY + 160);

        // Linhas divisórias
        p.line(startingX + 100, startingY + 170, finalX - 100, startingY + 170);
        p.line(startingX + 200, startingY + 140, startingX + 200, startingY + 400);
        p.line(finalX - 200, startingY + 140, finalX - 200, startingY + 400);

        for(int i = 0; i < scores.size(); i++) {
            ParseScore score = scores.get(i+1);
            p.textAlign(PApplet.LEFT, PApplet.BOTTOM);
            p.text(i+1, startingX + 100, startingY + 200 + i * 24);
            p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
            p.text(score.username(), (float) p.width / 2, startingY + 200 + i * 24);
            p.textAlign(PApplet.RIGHT, PApplet.BOTTOM);
            p.text(score.score(), finalX - 100, startingY + 200 + i * 24);
        }

        if(!message.isEmpty()) {
            p.text(message, 300, 180);
        }

        // Linha divisória
        p.fill(0);
        p.line(startingX + 50, startingY + 440, finalX - 50, startingY + 440);

        // Rodapé
        p.textSize(18);
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("[M] RETURN TO MENU", centerX, startingY + 480);
    }

    public void handleKey(char key, int keyCode) {
        if (key == 'm' || key == 'M') {
            manager.setState(GameState.MENU);
        }
    }

    public void onGetScoreboardSuccess(String payload) {
        message = "";
        scores.clear();

        parseScoreboard(payload, scores);
        manager.setState(GameState.SCOREBOARD);
    }

    public void onGetScoreboardFail(String payload) {
        message = payload;
    }
}
