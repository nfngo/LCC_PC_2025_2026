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
        float startingX = ((float) p.width - 600) / 2f; // 340
        float startingY = ((float) p.height - 500) / 2f; // 110
        float finalX = startingX + 600;
        float centerX = (float) p.width / 2f;

        // 1. Caixa do menu
        p.fill(240);
        p.stroke(0);
        p.strokeWeight(4);
        p.rect(startingX, startingY, 600, 500);

        // 2. Título (Aumentado para destaque)
        p.fill(0);
        p.textSize(42);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("GAME OVER", centerX, startingY + 40);

        // 3. Mensagem (Vencedor)
        p.textSize(28);
        p.text(message, centerX, startingY + 110);

        // --- Configuração da Tabela ---
        float tableTop = startingY + 180;
        float rowHeight = 30;
        // Definimos as margens laterais da tabela dentro da caixa (80px de cada lado)
        float tableLeft = startingX + 80;
        float tableRight = finalX - 80;

        // 4. Cabeçalhos da Tabela
        p.textSize(16);
        p.fill(100); // Cinza para os cabeçalhos
        p.textAlign(PApplet.CENTER, PApplet.BOTTOM);

        p.text("RANK", tableLeft + 40, tableTop);         // Coluna 1
        p.text("PLAYER", centerX, tableTop);              // Coluna 2
        p.text("SCORE", tableRight - 40, tableTop);       // Coluna 3

        // Linha horizontal principal (Header)
        p.stroke(0);
        p.strokeWeight(2);
        p.line(tableLeft, tableTop + 5, tableRight, tableTop + 5);

        // 5. Desenho dos Scores
        p.fill(0);
        p.textSize(18);

        for (int i = 0; i < scores.size() && i < 6; i++) { // Limitado a 6 para caber no espaço
            ParseScore score = scores.get(i + 1);
            float yPos = tableTop + 30 + (i * rowHeight);

            // Alinhamento centralizado em relação às colunas do cabeçalho
            p.textAlign(PApplet.CENTER, PApplet.CENTER);

            // Rank
            p.text(i + 1, tableLeft + 40, yPos);
            // Player Name
            p.text(score.username(), centerX, yPos);
            // Score
            p.text(score.score(), tableRight - 40, yPos);

            // Linhas horizontais subtis entre jogadores (opcional)
            p.stroke(220);
            p.strokeWeight(1);
            p.line(tableLeft, yPos + 15, tableRight, yPos + 15);
        }

        // 6. Rodapé (Separado por linha grossa)
        p.stroke(0);
        p.strokeWeight(3);
        p.line(startingX + 60, startingY + 430, finalX - 60, startingY + 430);

        p.fill(0);
        p.textSize(16);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("[M] MAIN MENU | [S] SCOREBOARD", centerX, startingY + 450);
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
