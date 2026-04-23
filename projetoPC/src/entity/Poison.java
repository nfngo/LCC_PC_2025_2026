package entity;

import processing.core.PApplet;

public class Poison extends Avatar {

    public Poison(PApplet p, float x, float y, float r) {
        super(p, x, y, r, p.color(255,0,0));
    }

    @Override
    public void update() {}
}
