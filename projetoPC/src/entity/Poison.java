package entity;

import processing.core.PApplet;

public class Poison extends Avatar {

    public Poison(PApplet p, int id, float x, float y, float r, long timestamp) {
        super(p, id, x, y, r, p.color(220,0,0), timestamp);
    }

    @Override
    public void update() {}
}
