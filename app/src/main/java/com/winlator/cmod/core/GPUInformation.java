package com.winlator.cmod.core;

import android.content.Context;
import android.util.Log;

public abstract class GPUInformation {

    public static boolean isAdrenoGPU(Context context) {
        String renderer = getRenderer(null, context);
        return renderer != null && renderer.toLowerCase().contains("adreno");
    }

    public static boolean isDriverSupported(String driverName, Context context) {
        // 🚀 BYPASS VORTEK MALI MULTI-PERFIL: Obligamos a Java a dar por válido el driver sin verificar hardware de Adreno
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            Log.d("GPUInformation", "Vortek Mali detectado en perfiles: Saltando validaciones de Qualcomm.");
            return true;
        }

        if (!isAdrenoGPU(context) && !driverName.equals("System"))
            return false;

        String renderer = getRenderer(driverName, context);
        return renderer != null && !renderer.toLowerCase().contains("unknown");
    }

    // 🚨 RESTAURACIÓN CRÍTICA JNI: Los nombres nativos vuelven a ser idénticos al C++ original para evitar fallos de Javac
    public native static String getVulkanVersion(String driverName, Context context);
    public native static int getVendorID(String driverName, Context context);
    
    // 🛡️ ESCUDO DE PROTOCÓLO NATIVO: Protegemos el método getRenderer para que si el C++ de winlator original 
    // devuelve NULL al no entender el driver de Vortek, Java intercepte el puntero y devuelva "Mali-Vortek" evitando el crash.
    private native static String getRendererNative(String driverName, Context context);
    
    public static String getRenderer(String driverName, Context context) {
        if (driverName != null && driverName.contains("vortek")) {
            return "Mali-Vortek-Zink";
        }
        try {
            String res = getRendererNative(driverName, context);
            return res != null ? res : "System";
        } catch (Exception e) {
            return "System";
        }
    }

    public native static String[] enumerateExtensions(String driverName, Context context);

    static {
        // 🚀 INYECCIÓN MAESTRA ESTÁTICA: Cargamos el motor gráfico de Vortek junto al núcleo de Winlator
        // Esto evita el UnsatisfiedLinkError en sistemas híbridos
        try {
            System.loadLibrary("vortekrenderer");
        } catch (UnsatisfiedLinkError e) {
            Log.e("GPUInformation", "No se pudo cargar libvortekrenderer.so de forma directa", e);
        }
        System.loadLibrary("winlator");
    }
}
