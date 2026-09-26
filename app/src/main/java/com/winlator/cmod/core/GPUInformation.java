package com.winlator.cmod.core;

import android.content.Context;

public abstract class GPUInformation {

    public static boolean isAdrenoGPU(Context context) {
        return getRenderer(null, context).toLowerCase().contains("adreno");
    }

    public static boolean isDriverSupported(String driverName, Context context) {
        // 🚀 BYPASS VORTEK: Permitimos que el driver pase la validación del sistema aunque no sea Adreno
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            return true;
        }

        if (!isAdrenoGPU(context) && !driverName.equals("System"))
            return false;

        String renderer = getRenderer(driverName, context);

        return !renderer.toLowerCase().contains("unknown");
    }

    // 🚀 ESCUDO JAVA PARA MÉTODOS NATIVOS (Evita que Vortek rompa la librería C++)
    public static String getVulkanVersion(String driverName, Context context) {
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            return "1.3.0"; // Versión requerida por el backend Zink
        }
        return getVulkanVersionNative(driverName, context);
    }

    public static int getVendorID(String driverName, Context context) {
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            return 0x10de; // Simulamos NVIDIA para máxima compatibilidad con juegos
        }
        return getVendorIDNative(driverName, context);
    }

    public static String getRenderer(String driverName, Context context) {
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            return "Vortek Mesa Zink (Mali)";
        }
        return getRendererNative(driverName, context);
    }

    public static String[] enumerateExtensions(String driverName, Context context) {
        if (driverName != null && (driverName.equals("vortek-2.1.tzst") || driverName.contains("vortek"))) {
            return new String[]{"VK_KHR_surface", "VK_KHR_android_surface", "VK_KHR_swapchain"};
        }
        return enumerateExtensionsNative(driverName, context);
    }

    // Vinculaciones nativas reales renombradas para poder ser interceptadas de forma segura
    private native static String getVulkanVersionNative(String driverName, Context context);
    private native static int getVendorIDNative(String driverName, Context context);
    private native static String getRendererNative(String driverName, Context context);
    private native static String[] enumerateExtensionsNative(String driverName, Context context);

    static {
        System.loadLibrary("winlator");
    }
}
