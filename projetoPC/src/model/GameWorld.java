package model;

import network.ParseResult;
import processing.core.PApplet;
import entity.*;

import java.util.*;

import static network.MessageParser.parseDelta;
import static network.MessageParser.parseGameState;

public class GameWorld {

    private final PApplet p;

    private final Map<Integer, Player> playersMap;
    private final Map<Integer, Avatar> objects;

    private Player self;
    private int score = 0;

    public GameWorld(PApplet p) {
        this.p = p;
        this.playersMap = new HashMap<>();
        this.objects = new HashMap<>();
    }

    public void applyState(String payload) {
        ParseResult result = parseGameState(p, payload, playersMap, objects);

        if (result.hasSelf()) {
            this.self = result.self();
        }
    }

    public void applyDelta(String payload) {
        this.score = parseDelta(p, payload, playersMap, objects);
    }

    public void update() {
        for (Player p : playersMap.values()) {
            p.update();
        }

        for (Avatar a : objects.values()) {
            a.update();
        }
    }

    public void draw() {
        // objetos
        for (Avatar a : objects.values()) {
            a.show();
        }

        // Jogadores
        for (Player p : playersMap.values()) {
            if(p != self) p.show();
        }

        // Desenhar self em último para ficar "por cima"
        self.show();

        drawHUD();
    }

    public void reset() {
        playersMap.clear();
        objects.clear();
        self = null;
    }

    void drawHUD() {
        p.fill(0);
        p.textSize(14);
        p.textAlign(PApplet.LEFT);

        // Pontuação atual
        p.text("Score: " + score, 10, 30);

        p.text("Controls:", 10, p.height - 60);
        p.text("UP - Move", 10, p.height - 45);
        p.text("LEFT/RIGHT - Rotate", 10, p.height - 30);
    }

    public Player getSelf() {
        return self;
    }

    public void setSelf(Player self) {
        this.self = self;
    }
}