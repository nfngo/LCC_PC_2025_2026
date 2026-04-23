package input;

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
        if (keyCode == 38) up = state;
        if (keyCode == 37) left = state;
        if (keyCode == 39) right = state;
    }

    public String serialize() {
        return (up?1:0) + "," + (left?1:0) + "," + (right?1:0) + "\n";
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
