package input;

import processing.core.PApplet;

public class InputHandler {

    public boolean up, left, right;
    private String lastSerialized = "";

    public void keyPressed(char key, int keyCode) {
        updateKey(keyCode, true);
    }

    public void keyReleased(char key, int keyCode) {
        updateKey(keyCode, false);
    }

    private void updateKey(int keyCode, boolean state) {
        if (keyCode == PApplet.UP)    up = state;
        if (keyCode == PApplet.LEFT)  left = state;
        if (keyCode == PApplet.RIGHT) right = state;
    }

    public String serialize() {
        return "INPUT," + (left?1:0) + "," + (up?1:0) + "," + (right?1:0);
    }

    // Verifica se o input mudou desde a última verificação
    public boolean hasChanged() {
        String current = serialize();
        if (!current.equals(lastSerialized)) {
            lastSerialized = current;
            return true;
        }
        return false;
    }
}
