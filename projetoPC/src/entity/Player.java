package entity;

import processing.core.PApplet;

public class Player extends Avatar {

    private float angle;
    private float targetAngle;
    private boolean isSelf;
    private float dx, dy;

    public Player(PApplet p, int id, float x, float y, float radius, long timestamp, boolean isSelf) {
        super(p, id, x, y, radius, p.color(0), timestamp);
        this.isSelf = isSelf;
    }

    @Override
    public void update() {
        super.update();
        angle = PApplet.lerp(angle, targetAngle, interpolationFactor);
        // Direção
        dx = x + PApplet.cos(angle) * radius;
        dy = y + PApplet.sin(angle) * radius;
    }

    @Override
    public void show() {
        super.show();

        p.stroke(isSelf ? p.color(0,0,255) : p.color(255,0,0));
        p.noFill();
        p.circle(x, y, radius * 2);

        p.line(x, y, dx, dy);

        // ID
        p.fill(0);
        p.text("P" + id, x - 10, y - radius - 5);
    }

    public void updateFromServer(float x, float y, float r, float angle, long timestamp) {
        super.updateFromServer(x, y, r, timestamp);
        this.targetAngle = angle;
    }

    public void setSelf(boolean self) {
        isSelf = self;
    }
}
