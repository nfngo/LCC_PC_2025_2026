package network;

import input.InputHandler;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.util.LinkedList;
import java.util.Queue;
import java.util.concurrent.locks.ReentrantLock;

public class ClientConnection {

    private static final int MAX_EVENT_QUEUE_SIZE = 50;
    private static final int MAX_WORLD_QUEUE_SIZE = 200;

    private Socket socket;
    private PrintWriter out;
    private BufferedReader in;

    private final String host;
    private final int port;
    private volatile boolean connected;

    // As listas ligadas permitem adição e remoção de elementos em tempo constante (O(1))
    // Queue de eventos de atualização do mundo/jogo
    private final Queue<String> stateQueue = new LinkedList<>();
    // Queue de estados (navegação entre menus)
    private final Queue<String> eventQueue = new LinkedList<>();

    // Locks para controlo de concorrência
    private final ReentrantLock stateLock = new ReentrantLock();
    private final ReentrantLock eventLock = new ReentrantLock();


    public ClientConnection(String host, int port) {
        this.host = host;
        this.port = port;
        this.connected = false;
    }

    public boolean connect() {
        if(connected) {
            return connected;
        }
        try {
            socket = new Socket(host, port);

            out = new PrintWriter(socket.getOutputStream(), true);
            in = new BufferedReader(
                    new InputStreamReader(socket.getInputStream())
            );

            connected = true;
            startListening();

            System.out.println("Connected to server");
            return connected;

        } catch (Exception e) {
            System.out.println("Connection failed: " + e.getMessage());
            markDisconnected();
            return connected;
        }
    }

    // Thread de rede (comunicação com o servidor)
    public void startListening() {
       new Thread(() -> {
            try {
                String line;
                while((line = in.readLine()) != null) {
                    if (line.startsWith("STATE") || line.startsWith("DELTA")) {
                        stateLock.lock();
                        try {
                            if (stateQueue.size() >= MAX_WORLD_QUEUE_SIZE) {
                                stateQueue.clear();
                            } else {
                                stateQueue.add(line);
                            }
                        } finally {
                            stateLock.unlock();
                        }
                    } else {
                        eventLock.lock();
                        try {
                            if (eventQueue.size() > MAX_EVENT_QUEUE_SIZE) {
                                eventQueue.poll();
                            }
                            eventQueue.add(line);
                        } finally {
                            eventLock.unlock();
                        }
                    }
                }
            } catch (IOException e) {
                // conexão encerrada (intencionalmente ou por erro)
                System.out.println("Connection closed");
            } finally {
                markDisconnected();
            }
        }, "NetworkThread").start();
    }

    // Obter último estado
    public String pollState() {
        stateLock.lock();
        try {
            return stateQueue.poll();
        } finally {
            stateLock.unlock();
        }
    }

    // Obter último evento
    public String pollEvent() {
        eventLock.lock();
        try {
            return eventQueue.poll();
        } finally {
            eventLock.unlock();
        }
    }

    // Envio de mensagens
    public void send(String msg) {
        if (!connected) return;

        // Forçar presença de \n para evitar bugs
        if (!msg.endsWith("\n")) {
            msg += "\n";
        }

        try {
            out.print(msg);
            out.flush();

            if (out.checkError()) {
                throw new IOException("Error sending message");
            }

        } catch (Exception e) {
            System.out.println("Send failed: " + e.getMessage());
            connected = false;
        }
    }

    // Envio de mensagens específicas de input
    public void sendInput(InputHandler input) {
        send(input.serialize());
    }

    // Estado da ligação
    public boolean isConnected() {
        return connected && socket != null && socket.isConnected() && !socket.isClosed();
    }

    private void markDisconnected() {
        connected = false;

        // Fechar socket, in e out
        try {
            if (socket != null) {
                socket.close();
            }
        } catch (IOException ignored) {
        }

        if (out != null) {
            out.close();
        }

        socket = null;
        out = null;
        in = null;

        // Limpar queues
        stateLock.lock();
        try {
            stateQueue.clear();
        } finally {
            stateLock.unlock();
        }

        eventLock.lock();
        try {
            eventQueue.clear();
        } finally {
            eventLock.unlock();
        }
    }

    // Fechar ligação
    public void disconnect() {
        markDisconnected();
        System.out.println("Disconnected");
    }
}