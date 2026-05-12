package entity;

import processing.core.PApplet;
import core.*;

public abstract class Avatar implements Renderable, Updatable {

    protected PApplet p;
    protected int id;

    protected float x, y;
    protected float startX, startY;
    protected float targetX, targetY;

    protected float radius;
    protected int color;

    protected long timestamp;
    protected long targetTimestamp;

    protected long interpolationStartTime;
    protected long interpolationDuration = 50;

    protected float interpolationFactor;

    public Avatar(PApplet p, int id, float x, float y, float radius, int color, long timestamp) {
        this.id = id;
        this.p = p;
        this.x = x;
        this.y = y;

        this.startX = x;
        this.startY = y;
        this.targetX = x;
        this.targetY = y;

        this.radius = radius;
        this.color = color;
        this.timestamp = timestamp;
        this.targetTimestamp = timestamp;
        this.interpolationStartTime = System.currentTimeMillis();
    }

    public int getId() {
        return id;
    }

    @Override
    public void update() {
        long now = System.currentTimeMillis();
        long elapsed = now - interpolationStartTime;

        interpolationFactor = interpolationDuration <= 0
                ? 1.0f
                : (float) elapsed / interpolationDuration;

        interpolationFactor = PApplet.constrain(interpolationFactor, 0.0f, 1.0f);

        x = PApplet.lerp(startX, targetX, interpolationFactor);
        y = PApplet.lerp(startY, targetY, interpolationFactor);
    }

    @Override
    public void show() {
        p.fill(color);
        p.noStroke();
        p.circle(x, y, radius * 2);
    }

    public void updateFromServer(float x, float y, float radius, long timestamp) {
        this.startX = this.x;
        this.startY = this.y;

        this.targetX = x;
        this.targetY = y;

        // Calcular intervalo entre snapshots
        long interval = timestamp - this.targetTimestamp;
        if (interval > 0 && interval < 1000) {
            this.interpolationDuration = interval;
        } else {
            this.interpolationDuration = 50;
        }

        // Atualizar timestamps
        // timestamp = antigo targetTimestamp
        // targetTimestamp = timestamp recebido do servidor
        this.timestamp = this.targetTimestamp;
        this.targetTimestamp = timestamp;
        // Registar quando foi recebida a mensagem do servidor para calcular
        // o fator de interpolação
        this.interpolationStartTime = System.currentTimeMillis();

        this.radius = radius;
    }
}