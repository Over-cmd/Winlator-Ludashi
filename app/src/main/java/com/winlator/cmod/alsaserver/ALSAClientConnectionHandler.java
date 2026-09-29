package com.winlator.cmod.alsaserver;

import com.winlator.cmod.xconnector.Client;
import com.winlator.cmod.xconnector.ConnectionHandler;

public class ALSAClientConnectionHandler implements ConnectionHandler {
    @Override
    public void handleNewConnection(Client client) {
        // 🛡️ REPARACIÓN ESTRUCTURAL SÍNCRONA:
        // Inicializamos los flujos y el objeto tag de forma inmediata en el hilo actual.
        // Esto garantiza que getTag() jamás devuelva null cuando el juego empiece a mandar peticiones,
        // eliminando por completo los cierres directos del contenedor.
        client.createIOStreams();
        client.setTag(new ALSAClient());
    }

    @Override
    public void handleConnectionShutdown(Client client) {
        if (client.getTag() instanceof ALSAClient) {
            ((ALSAClient)client.getTag()).release();
        }
    }
}
