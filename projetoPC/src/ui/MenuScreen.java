package ui;

import processing.core.PApplet;
import state.*;
import network.ClientConnection;

public class MenuScreen {

    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    public MenuScreen(PApplet p, StateManager manager, ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        float startingX = ((float) p.width - 600)/2;
        float startingY = ((float) p.height - 500)/2;

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
        p.text("MAIN MENU", centerX, startingY + 100);

        p.textSize(28);
        p.textAlign(PApplet.CENTER);
        p.text("1 - PLAY", centerX, startingY + 200);
        p.text("2 - SCOREBOARD", centerX, startingY + 260);
        p.fill(220, 0 , 0);
        p.text("3 - LOGOUT", centerX, startingY + 320);

        // Linha divisória
        p.fill(0);
        p.line(startingX + 50, startingY + 440, startingX + 550, startingY + 440);

        // Rodapé
        p.textSize(18);
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);
        p.text("[UP/DOWN] NAVIGATE | [ENTER] SELECT", centerX, startingY + 480);
    }

    public void handleKey(char key, int keyCode) {

        if (key == '1') {
            play();

        } else if (key == '2') {
            getScoreboard();

        } else if (key == '3') {
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