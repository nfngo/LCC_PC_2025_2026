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

    private Socket socket;
    private PrintWriter out;
    private BufferedReader in;

    private boolean connected = false;

    // Se não for possível utilizar ConcurrentLinkedQueue, utilizamos Queues implementadas com listas ligadas.
    // As listas ligadas permitem adição e remoção de elementos em tempo constante (O(1))
    // Queue de estados (navegação entre menus)
    private final Queue<String> stateQueue = new LinkedList<>();
    // Queue de eventos de atualização do mundo/jogo
    private final Queue<String> eventQueue = new LinkedList<>();

    // Locks para controlo de concorrência
    private final ReentrantLock stateLock = new ReentrantLock();
    private final ReentrantLock eventLock = new ReentrantLock();


    public ClientConnection(String host, int port) {
        connect(host, port);
        startListening();
    }

    private void connect(String host, int port) {
        try {
            socket = new Socket(host, port);

            out = new PrintWriter(socket.getOutputStream(), true);
            in = new BufferedReader(
                    new InputStreamReader(socket.getInputStream())
            );

            connected = true;
            System.out.println("Connected to server");

        } catch (Exception e) {
            System.out.println("Connection failed: " + e.getMessage());
            connected = false;
        }
    }

    // Thread de rede (comunicação com o servidor)
    private void startListening() {
        /*
        Implementação da Thread com Lambda
        - Vantagem: É muito mais curto e evita "boilerplate" (código repetitivo).
          Como a interface Runnable é uma interface funcional (apenas tem o método run()),
          a lambda permite focar apenas na lógica.
       */
       new Thread(() -> {
            try {
                String line;
                while((line = in.readLine()) != null) {
                    if (line.startsWith("STATE")) {
                        stateLock.lock();
                        try {
                            stateQueue.clear();
                            stateQueue.add(line);
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
            }
        }, "NetworkThread").start();
    }

    // Obter último estado
    public String poolState() {
        stateLock.lock();
        try {
            return stateQueue.poll();
        } finally {
            stateLock.unlock();
        }
    }

    // Obter último evento
    public String poolEvent() {
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
        return connected && socket != null && socket.isConnected();
    }

    // Fechar ligação
    // Ao fazer socket.close(), será lançada uma IOException dentro da thread (no readLine()),
    // o que fará com que o bloco catch seja executado e a thread termine a sua execução com segurança.
    public void disconnect() {
        try {
            if (socket != null) socket.close();
            connected = false;
            System.out.println("Disconnected");
        } catch (IOException e) {
            System.out.println("Error closing connection");
        }
    }
}