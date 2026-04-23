package model;

import network.ParseResult;
import processing.core.PApplet;
import entity.*;

import java.util.*;

import static network.MessageParser.parseGameState;

public class GameWorld {

    private final PApplet p;

    private final Map<Integer, Player> playersMap;
    private final List<Avatar> objects;

    private Player self;

    public GameWorld(PApplet p) {
        this.p = p;
        this.playersMap = new HashMap<>();
        this.objects = new ArrayList<>();
    }

    public void applyState(String payload) {
        ParseResult result = parseGameState(p, payload, playersMap, objects);

        if (result.hasSelf()) {
            this.self = result.self();
        }
    }

    public void update() {
        for (Player p : playersMap.values()) {
            p.update();
        }

        for (Avatar a : objects) {
            a.update();
        }
    }

    public void draw() {
        // jogadores
        for (Player p : playersMap.values()) {
            p.show();
        }

        // objetos
        for (Avatar a : objects) {
            a.show();
        }
    }

    public void reset() {
        playersMap.clear();
        objects.clear();
        self = null;
    }

    public void onGameOver(String payload) {
        System.out.println("Game Over!");

        // extrair score do payload
        // ex: GAME_OVER,150
        // possibilidade de mostrar no ecrã
        if (payload != null && !payload.isEmpty()) {
            System.out.println("Final score: " + payload);
        }

        reset();
    }

    public Player getSelf() {
        return self;
    }

    public void setSelf(Player self) {
        this.self = self;
    }
}