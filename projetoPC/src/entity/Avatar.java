package entity;

import processing.core.PApplet;
import core.*;

public abstract class Avatar implements Renderable, Updatable {

    protected PApplet p;
    protected int id;
    protected float x, y;
    protected float targetX, targetY;
    protected float radius;
    protected int color;
    protected long timestamp;
    protected long targetTimestamp;
    protected float interpolationFactor;

    public Avatar(PApplet p, int id, float x, float y, float radius, int color, long timestamp) {
        this.id = id;
        this.p = p;
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.color = color;
        this.timestamp = timestamp;

        this.targetX = x;
        this.targetY = y;
        this.targetTimestamp = timestamp;
    }

    public int getId() {
        return id;
    }

    @Override
    public void update() {
        long currentTime = System.currentTimeMillis();

        // Calcular quanto tempo passou desde que o servidor enviou a última mensagem
        long elapsedTime = currentTime - targetTimestamp;
        // Calcular o intervalo entre as duas últimas mensagens do servidor
        long interval = targetTimestamp - timestamp;

        // Fallback para evitar divisão por zero
        if (interval <= 0) interval = 50;

        // Calcular o fator de interpolação (0.0 a 1.0)
        interpolationFactor = (float) elapsedTime / interval;
        x = PApplet.lerp(x, targetX, interpolationFactor);
        y = PApplet.lerp(y, targetY, interpolationFactor);
    }

    @Override
    public void show() {
        p.fill(color);
        p.noStroke();
        p.circle(x, y, radius * 2);
    }

    public void updateFromServer(float x, float y, float radius, long timestamp) {
        this.targetX = x;
        this.targetY = y;
        this.targetTimestamp = timestamp;
        this.radius = radius;
    }
}