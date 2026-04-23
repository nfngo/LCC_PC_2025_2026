package entity;

import processing.core.PApplet;

public class Food extends Avatar {

    public Food(PApplet p, float x, float y, float r) {
        super(p, x, y, r, p.color(0,255,0));
    }

    @Override
    public void update() {}
}
