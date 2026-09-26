package com.winlator.cmod.core;

import android.content.Context;

public abstract class GPUInformation {

    public static boolean isAdrenoGPU(Context context) {
        String renderer = getRenderer(null, context);
        return renderer != null && renderer.toLowerCase().contains("adreno");
    }

    public static boolean isDriverSupported(String driverName, Context context) {
        // 🚀 BYPASS VORTEK MALI: Si el driver es Vortek, saltamos la validación para que no lo rechace por no ser Adreno
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
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
    public native static String getRenderer(String driverName, Context context);
    public native static String[] enumerateExtensions(String driverName, Context context);

    static {
        System.loadLibrary("winlator");
    }
}
