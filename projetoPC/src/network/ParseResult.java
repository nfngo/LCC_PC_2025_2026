package network;

import entity.Player;

public record ParseResult(Player self, int selfId) {

    // Útil para verificar se o player local foi encontrado no payload
    public boolean hasSelf() {
        return self != null;
    }
}
