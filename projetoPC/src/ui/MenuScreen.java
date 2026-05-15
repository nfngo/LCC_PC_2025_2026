package ui;

import processing.core.PApplet;
import state.*;
import network.ClientConnection;

public class MenuScreen {

    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;
    private int selected = 0;

    public MenuScreen(PApplet p, StateManager manager, ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        float boxW = 600;
        float boxH = 500;
        float startingX = ((float) p.width - boxW)/2;
        float startingY = ((float) p.height - boxH)/2;

        float centerX = (float) p.width / 2;

        // Caixa do menu
        p.fill(240);
        p.stroke(0);
        p.strokeWeight(4);
        p.rect(startingX, startingY, boxW, boxH);

        // Título
        p.fill(0);
        p.textSize(42);
        // Alinhamento: centro, acima da posição onde começa
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("MAIN MENU", centerX, startingY + 100);

        p.textAlign(PApplet.CENTER, PApplet.CENTER);
        p.textSize(28);

        String playText = "PLAY";
        float playY = startingY + 200;
        p.text(playText, centerX, playY);

        String scoreboardText = "SCOREBOARD";
        float scoreboardY = startingY + 260;
        p.text(scoreboardText, centerX, startingY + 260);

        String logoutText = "LOGOUT";
        float logoutY = startingY + 320;
        p.fill(220, 0 , 0);
        p.text(logoutText, centerX, logoutY);

        // Círculo antes de play
        if(selected == 0){
            drawSelectionCircle(playText, playY);
        } else if(selected == 1){
            drawSelectionCircle(scoreboardText, scoreboardY);
        } else if(selected == 2) {
            drawSelectionCircle(logoutText, logoutY);
        }

        // Rodapé
        p.stroke(230);
        p.strokeWeight(1);
        p.line(startingX + 60, startingY + boxH - 35, startingX + boxW - 60, startingY + boxH - 35);

        p.noStroke();
        p.fill(50);
        p.textSize(16);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("[TAB] NAVIGATE | [ENTER] SELECT", centerX, startingY + boxH - 25);
    }

    public void drawSelectionCircle(String text, float startY) {
        float centerX = (float) p.width / 2;

        float msgWidth = p.textWidth(text);
        float circleX = centerX - (msgWidth / 2f) - 30;
        float circleSize = 30;

        p.fill(0);
        p.circle(circleX, startY, circleSize);
    }

    public void handleKey(char key, int keyCode) {

        if (key == '\t') {
            selected = (selected + 1) % 3;
        }

        else if (keyCode == PApplet.ENTER && selected == 0) {
            play();
        }

        else if (keyCode == PApplet.ENTER && selected == 1) {
            getScoreboard();
        }

        else if (keyCode == PApplet.ENTER && selected == 2) {
            logout();
        }
    }

    // Implementar métodos de feedback do servidor
    private void play() {
        conn.send("PLAY");
    }

    private void getScoreboard() {
        conn.send("SCOREBOARD");
    }

    private void logout() {
        conn.send("LOGOUT");
    }

}