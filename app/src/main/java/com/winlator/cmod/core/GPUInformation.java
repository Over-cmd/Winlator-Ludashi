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
        try {
            if (!isAdrenoGPU(context) && !driverName.equals("System"))
                return false;

            String renderer = getRenderer(driverName, context);
            return renderer != null && !renderer.toLowerCase().contains("unknown");
        } catch (Exception e) {
            Log.e("GPUInformation", "Error al comprobar soporte de driver", e);
            return driverName != null && !driverName.equals("System");
        }
    }

    public native static String getVulkanVersion(String driverName, Context context);
    public native static int getVendorID(String driverName, Context context);
    public native static String getRenderer(String driverName, Context context);
    public native static String[] enumerateExtensions(String driverName, Context context);

    static {
        System.loadLibrary("winlator");
    }
}
