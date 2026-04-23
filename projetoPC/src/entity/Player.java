package entity;

import processing.core.PApplet;

public class Player extends Avatar {

    private final int id;
    private float angle;
    private float targetAngle;
    private boolean isSelf;

    public Player(PApplet p, int id, float x, float y, float radius, boolean isSelf) {
        super(p, x, y, radius, p.color(0));
        this.id = id;
        this.isSelf = isSelf;
    }

    @Override
    public void update() {
        super.update();
        angle = PApplet.lerp(angle, targetAngle, 0.2f);
    }

    @Override
    public void show() {
        super.show();

        p.stroke(isSelf ? p.color(0,0,255) : p.color(255,0,0));
        p.noFill();
        p.circle(x, y, radius * 2);

        // Direção
        float dx = x + PApplet.cos(angle) * radius;
        float dy = y + PApplet.sin(angle) * radius;
        p.line(x, y, dx, dy);

        // ID
        p.fill(0);
        p.text("P" + id, x - 10, y - radius - 5);
    }

    public void updateFromServer(float x, float y, float r, float angle) {
        super.updateFromServer(x, y, r);
        this.targetAngle = angle;
    }

    public int getId() {
        return id;
    }

    public void setSelf(boolean self) {
        isSelf = self;
    }
}
