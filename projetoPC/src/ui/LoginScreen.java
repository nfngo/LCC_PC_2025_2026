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
    private int selected = 0;

    private String message = ""; // feedback (erro/sucesso)

    public LoginScreen(PApplet p, StateManager manager, ClientConnection conn) {
        this.p = p;
        this.manager = manager;
        this.conn = conn;
    }

    public void update() {}

    public void draw() {
        float boxW = 600;
        float boxH = 500;
        float startX = (p.width - boxW) / 2f;
        float startY = (p.height - boxH) / 2f;
        float centerX = p.width / 2f;

        // Caixa Principal
        p.fill(240);
        p.stroke(0);
        p.strokeWeight(4);
        p.rect(startX, startY, boxW, boxH);

        // Título
        p.noStroke();
        p.fill(0);
        p.textSize(32);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("WELCOME TO CIRCLE HUNT", centerX, startY + 20);

        p.stroke(0);
        p.strokeWeight(2);
        p.line(startX, startY + 60, startX + boxW, startY + 60);
        p.noStroke();

        // Username e Password
        p.textSize(24);

        float usernameY = startY + 120;
        float usernameTextY = usernameY + 40;

        float passwordY = usernameTextY + 60;
        float passwordTextY = passwordY + 40;

        // Campos de texto
        p.textSize(24);

        p.fill(0);
        p.textAlign(PApplet.CENTER, PApplet.CENTER);

        // USERNAME
        p.text("USERNAME:", centerX, usernameY);
        p.text(username, centerX, usernameTextY);
        p.stroke(230);
        p.line(startX + 120, usernameTextY + 18, startX + boxW - 120, usernameTextY + 18);

        // PASSWORD
        p.text("PASSWORD:", centerX, passwordY);
        p.text("*".repeat(password.length()), centerX, passwordTextY);
        p.line(startX + 120, passwordTextY + 15, startX + boxW - 120, passwordTextY + 15);

        if (isTypingUser()) {
            // Linha do username
            p.stroke(159, 199, 227);
            p.line(startX + 120, usernameTextY + 18, startX + boxW - 120, usernameTextY + 18);
        } else if(isTypingPassword()) {
            // Linha da password
            p.stroke(159, 199, 227);
            p.line(startX + 120, passwordTextY + 15, startX + boxW - 120, passwordTextY + 15);
        }
        p.noStroke();

        // mensagem feedback
        p.textSize(18);
        p.fill(180, 0, 0);
        p.text(message, centerX, passwordTextY + 40);
        p.fill(0);

        p.textAlign(PApplet.CENTER, PApplet.CENTER);
        p.textSize(24);

        String loginText = "LOGIN";
        float loginY = startY + 340;
        p.text("LOGIN", centerX, loginY);

        String registerText = "REGISTER";
        float registerY = loginY + 40;
        p.text(registerText, centerX, registerY);

        String deleteText = "DELETE ACCOUNT";
        float deleteY = registerY + 40;
        p.fill(220, 0 , 0);
        p.text(deleteText, centerX, deleteY);
        p.fill(0);

        // Círculo antes de play
        if(selected == 2){
            drawSelectionCircle(loginText, loginY);
        } else if(selected == 3){
            drawSelectionCircle(registerText, registerY);
        } else if(selected == 4) {
            drawSelectionCircle(deleteText, deleteY);
        }

        // Rodapé
        p.stroke(230);
        p.strokeWeight(1);
        p.line(startX + 60, startY + boxH - 35, startX + boxW - 60, startY + boxH - 35);

        p.noStroke();
        p.fill(50);
        p.textSize(16);
        p.textAlign(PApplet.CENTER, PApplet.TOP);
        p.text("[TAB] NAVIGATE | [ENTER] SELECT", centerX, startY + boxH - 25);
    }

    private boolean isTypingUser() {
        return selected == 0;
    }

    private boolean isTypingPassword() {
        return selected == 1;
    }

    public void drawSelectionCircle(String text, float startY) {
        float centerX = (float) p.width / 2;

        float msgWidth = p.textWidth(text);
        float circleX = centerX - (msgWidth / 2f) - 26;
        float circleSize = 26;

        p.fill(0);
        p.circle(circleX, startY, circleSize);
    }

    public void handleKey(char key, int keyCode) {

        if (key == '\t') {
            selected = (selected + 1) % 5;

        } else if (keyCode == PApplet.ENTER) {
            if(selected == 2) {
                login();
            } else if(selected == 3) {
                register();
            } else if(selected == 4) {
                deleteAccount();
            }
        } else if (keyCode == PApplet.BACKSPACE) {
            handleBackspace();

        } else if (key != PApplet.CODED) {
            handleTyping(key);
        }
    }

    private boolean invalidFields() {
        if (username.isEmpty() || password.isEmpty()) {
            message = "Fill all fields";
            return true;
        }
        return false;
    }

    private boolean isDisconnected() {
        if(!conn.isConnected()) {
            boolean connected = conn.connect();

            if(!connected) {
                message = "Unable to connect to server...";
                return true;
            }
        }
        return false;
    }

    private void login() {
        if(invalidFields()) return;

        if(isDisconnected()) return;

        conn.send("LOGIN," + username + "," + password);
    }

    private void register() {
        if(invalidFields()) return;

        if(isDisconnected()) return;

        conn.send("REGISTER," + username + "," + password);
    }

    private void deleteAccount() {
        if(invalidFields()) return;

        if(isDisconnected()) return;

        conn.send("DELETE_ACCOUNT," + username + "," + password);
    }

    public void reset() {
        username = "";
        password = "";
        message = "";
        typingUser = true;
    }

    private void handleBackspace() {
        if (isTypingUser() && !username.isEmpty()) {
            username = username.substring(0, username.length()-1);
        } else if (isTypingPassword() && !password.isEmpty()) {
            password = password.substring(0, password.length()-1);
        }
    }

    private void handleTyping(char key) {
        if (isTypingUser()) {
            username += key;
        } else if (isTypingPassword()) {
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
        conn.disconnect();
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

    public void connectionLost() {
        message = "Disconnected from server";
    }

    public void onError(String payload) {
        message = "Server error: " + payload;
    }
}
