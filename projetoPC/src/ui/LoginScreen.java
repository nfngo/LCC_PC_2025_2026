package ui;

import processing.core.PApplet;
import state.*;
import network.ClientConnection;

public class LoginScreen {

    private final PApplet p;
    private final StateManager manager;
    private final ClientConnection conn;

    private String username = "";
    private String password = "";
    private boolean typingUser = true;

    private String message = ""; // feedback (erro/sucesso)

    public LoginScreen(PApplet p, StateManager manager, ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        p.fill(0);
        p.textSize(32);
        p.text("LOGIN / REGISTER", 250, 100);

        p.textSize(16);

        // campos
        p.text("Username: " + username, 200, 200);
        p.text("Password: " + "*".repeat(password.length()), 200, 240);

        // highlight campo ativo
        if (typingUser) {
            p.line(200, 205, 400, 205);
        } else {
            p.line(200, 245, 400, 245);
        }

        // instruções
        p.text("TAB - Switch field", 200, 300);
        p.text("ENTER - Login", 200, 320);
        p.text("ALT - Register", 200, 340);
        p.text("DEL - Delete account", 200, 360);

        // mensagem feedback
        p.fill(255, 0, 0);
        p.text(message, 200, 400);
    }

    public void handleKey(char key, int keyCode) {

        if (key == '\t') {
            typingUser = !typingUser;

        } else if (keyCode == PApplet.ENTER) {
            login();

        } else if (keyCode == PApplet.ALT) {
            register();

        } else if (keyCode == PApplet.DELETE) {
            deleteAccount();

        } else if (keyCode == PApplet.BACKSPACE) {
            handleBackspace();

        } else if (key != PApplet.CODED) {
            handleTyping(key);
        }
    }

    private void login() {
        if (username.isEmpty() || password.isEmpty()) {
            message = "Fill all fields";
            return;
        }

        conn.send("LOGIN," + username + "," + password);
    }

    private void register() {
        if (username.isEmpty() || password.isEmpty()) {
            message = "Fill all fields";
            return;
        }

        conn.send("REGISTER," + username + "," + password);
    }

    private void deleteAccount() {
        if(username.isEmpty() || password.isEmpty()) {
            message = "Fill all fields";
            return;
        }

        conn.send("DELETE_ACCOUNT," + username + "," + password);
    }

    public void reset() {
        username = "";
        password = "";
        message = "";
        typingUser = true;
    }

    private void handleBackspace() {
        if (typingUser && !username.isEmpty()) {
            username = username.substring(0, username.length()-1);
        } else if (!typingUser && !password.isEmpty()) {
            password = password.substring(0, password.length()-1);
        }
    }

    private void handleTyping(char key) {
        if (typingUser) {
            username += key;
        } else {
            password += key;
        }
    }

    // Receber feedback do servidor
    public void onLoginSuccess() {
        message = "";
        manager.setState(GameState.MENU);
    }

    public void onLoginFail(String payload) {
        if(payload.equals("invalid_credentials")) {
            message = "Invalid credentials";
            return;
        }

        if(payload.equals("user_already_logged_in")) {
            message = "User already logged in";
        }
    }

    public void onRegisterSuccess() {
        message = "Account registered successfully";
    }

    public void onRegisterFail(String payload) {
        if(payload.equals("user_exists")) {
            message = "User already exists";
        }
    }

    public void onLogoutSuccess() {
        reset();
        message = "Logged out successfully";
        manager.setState(GameState.LOGIN);
    }

    public void onDeleteSuccess() {
        reset();
        message = "Account deleted";
    }

    public void onDeleteFail(String payload) {
        if(payload.equals("invalid_credentials")) {
            message = "Invalid credentials";
        }
    }

    public void onError(String payload) {
        message = "Server error: " + payload;
    }
}
