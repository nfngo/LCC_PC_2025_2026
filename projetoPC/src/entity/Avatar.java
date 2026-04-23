package entity;

import processing.core.PApplet;
import core.*;

public abstract class Avatar implements Renderable, Updatable {

    protected PApplet p;
    protected float x, y;
    protected float targetX, targetY;
    protected float radius;
    protected int color;

    public Avatar(PApplet p, float x, float y, float radius, int color) {
        this.p = p;
        this.x = x;
        this.y = y;
        this.targetX = x;
        this.targetY = y;
        this.radius = radius;
        this.color = color;
    }

    @Override
    public void update() {
        x = PApplet.lerp(x, targetX, 0.2f);
        y = PApplet.lerp(y, targetY, 0.2f);
    }

    @Override
    public void show() {
        p.fill(color);
        p.noStroke();
        p.circle(x, y, radius * 2);
    }

    public void updateFromServer(float x, float y, float radius) {
        this.targetX = x;
        this.targetY = y;
        this.radius = radius;
    }
}