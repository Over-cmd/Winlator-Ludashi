package com.winlator.cmod.alsaserver;

import android.os.Process;
import com.winlator.cmod.xconnector.Client;
import com.winlator.cmod.xconnector.ConnectionHandler;

public class ALSAClientConnectionHandler implements ConnectionHandler {
    @Override
    public void handleNewConnection(final Client client) {
        // 🚀 INYECCIÓN MAESTRA MALI-AUDIO:
        // Sacamos la apertura de streams del bucle bloqueante gráfico y le clavamos
        // prioridad estricta de audio en segundo plano (THREAD_PRIORITY_AUDIO = -16).
        // Esto impide que el procesador pause la música cuando el renderizado de vídeo se sature.
        Thread audioThread = new Thread(new Runnable() {
            @Override
            public void run() {
                Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);
                client.createIOStreams();
                client.setTag(new ALSAClient());
            }
        });
        audioThread.setName("ALSA-Mali-AudioEngine");
        audioThread.start();
    }

    @Override
    public void handleConnectionShutdown(Client client) {
        if (client.getTag() instanceof ALSAClient) {
            ((ALSAClient)client.getTag()).release();
        }
    }
}
