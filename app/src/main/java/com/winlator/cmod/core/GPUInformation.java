package com.winlator.cmod.core;

import android.content.Context;
import android.util.Log;

public abstract class GPUInformation {

    public static boolean isAdrenoGPU(Context context) {
        try {
            String renderer = getRenderer(null, context);
            return renderer != null && renderer.toLowerCase().contains("adreno");
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean isDriverSupported(String driverName, Context context) {
        // 🚀 BYPASS VORTEK MALI MULTI-PERFIL: Obligamos a Java a dar por válido el driver sin verificar hardware de Adreno
        if (driverName != null && (driverName.equals("adrenotools-vortek.tzst") || driverName.contains("vortek"))) {
            Log.d("GPUInformation", "Vortek Mali detectado en perfiles: Saltando validaciones de Qualcomm.");
            return true;
        }

        // 🛡️ ESCUDO ANTI-CRASH TOTAL: Envolvemos las validaciones de cadenas en un try-catch.
        // Si el motor de C++ no reconoce el chip Mali o devuelve nulo, Java lo captura en silencio y no cierra la APK.
        try {
            if (!isAdrenoGPU(context) && !driverName.equals("System"))
                return false;

            String renderer = getRenderer(driverName, context);
            return renderer != null && !renderer.toLowerCase().contains("unknown");
        } catch (Exception e) {
            Log.e("GPUInformation", "Error al comprobar soporte de driver, aplicando bypass de seguridad", e);
            return driverName != null && !driverName.equals("System");
        }
    }

    // 🚨 RESTAURACIÓN CRÍTICA JNI: Los nombres nativos vuelven a ser EXACTAMENTE idénticos al C++ original
    // Esto repara de inmediato el UnsatisfiedLinkError al abrir o crear contenedores.
    public native static String getVulkanVersion(String driverName, Context context);
    public native static int getVendorID(String driverName, Context context);
    public native static String getRenderer(String driverName, Context context);
    public native static String[] enumerateExtensions(String driverName, Context context);

    static {
        // 🚀 SOLUCIÓN GANADORA DE FIN DE JUEGO: 
        // Quitamos loadLibrary("vortekrenderer") para corregir el crash fulminante del cargador.
        // Las llamadas de Vortek ya se resuelven de manera interna por debajo al cargar "winlator".
        System.loadLibrary("winlator");
    }
}
