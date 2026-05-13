package entity;

import processing.core.PApplet;

public class Food extends Avatar {

    public Food(PApplet p, int id, float x, float y, float r, long timestamp) {
        super(p,id, x, y, r, p.color(0,200,0), timestamp);
    }

    @Override
    public void update() {}
}
