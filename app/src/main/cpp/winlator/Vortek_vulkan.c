#include <jni.h>
#include <libgen.h>
#include <sys/stat.h>
#include <dlfcn.h>       // 🚀 CRÍTICO: Para usar dlopen de forma dinámica
#include <android/log.h>  // 🚀 CRÍTICO: Para imprimir logs de control en el sistema

#include "vk_context.h"
#include "vortek_serializer.h"
#include "request_handler.h"
#include "vulkan_helper.h"
#include "jni_utils.h"

#include "adrenotools/driver.h"

VulkanWrapper vulkanWrapper = {0};
bool vortekSerializerCastVkObject = true;

// 🚀 DISPARADOR ESTÁTICO JNI DE ALEXVORXX:
// En cuanto Android mapea libvortekrenderer.so, este método se ejecuta de primero
// en el hilo del sistema. Inyectamos libXlorie.so aquí para que amarre los relojes 
// multimedia de forma transparente en segundo plano sin bloquear el Linker central.
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    void* xlorie_handle = dlopen("libXlorie.so", RTLD_NOW | RTLD_GLOBAL);
    if (xlorie_handle) {
        __android_log_print(ANDROID_LOG_INFO, "VortekMain", "🚀 ¡ÉXITO! libXlorie.so acoplada al cargador JNI de Vortek.");
    } else {
        __android_log_print(ANDROID_LOG_WARN, "VortekMain", "No se pudo inyectar libXlorie.so en el arranque de JNI.");
    }
    return JNI_VERSION_1_6;
}

static void* openVulkanLibrary(JNIEnv* env, jstring nativeLibraryDir, jstring libvulkanPath) {
    void* libvulkan;
    if (libvulkanPath) {
        const char* nativeLibraryDirC = (*env)->GetStringUTFChars(env, nativeLibraryDir, NULL);
        const char* libvulkanPathC = (*env)->GetStringUTFChars(env, libvulkanPath, NULL);
        const char* libvulkanName = basename(libvulkanPathC);

        char libvulkanDir[PATH_MAX] = {0};
        strcpy(libvulkanDir, dirname(libvulkanPathC));
        strcat(libvulkanDir, "/");

        char* tmpDir;
        asprintf(&tmpDir, "%s%s", libvulkanDir, "tmp");
        mkdir(tmpDir, S_IRWXU | S_IRWXG);

        libvulkan = adrenotools_open_libvulkan(RTLD_NOW | RTLD_LOCAL, ADRENOTOOLS_DRIVER_CUSTOM, tmpDir, nativeLibraryDirC, libvulkanDir, libvulkanName, NULL, NULL);

        (*env)->ReleaseStringUTFChars(env, nativeLibraryDir, nativeLibraryDirC);
        (*env)->ReleaseStringUTFChars(env, libvulkanPath, libvulkanPathC);
    }
    else libvulkan = dlopen(LIBVULKAN_PATH, RTLD_NOW | RTLD_LOCAL);

    if (!libvulkan) println("vortek: unable to open libvulkan: %s", dlerror());
    return libvulkan;
}

JNIEXPORT jlong JNICALL
Java_com_winlator_xenvironment_components_VortekRendererComponent_createVkContext(JNIEnv *env,
                                                                                  jobject obj,
                                                                                  jint clientFd,
                                                                                  jobject options) {
    VkContext* context = createVkContext(env, obj, clientFd, options);
    return context ? (jlong)context : 0;
}

JNIEXPORT void JNICALL
Java_com_winlator_xenvironment_components_VortekRendererComponent_destroyVkContext(JNIEnv *env,
                                                                                   jobject obj,
                                                                                   jlong contextPtr) {
    destroyVkContext(env, (VkContext*)contextPtr);
}

JNIEXPORT void JNICALL
Java_com_winlator_xenvironment_components_VortekRendererComponent_initVulkanWrapper(JNIEnv *env,
                                                                                    jobject obj,
                                                                                    jstring nativeLibraryDir,
                                                                                    jstring libvulkanPath) {
    void* libvulkan = openVulkanLibrary(env, nativeLibraryDir, libvulkanPath);
    initVulkanWrapper(&vulkanWrapper, libvulkan);
}

JNIEXPORT jboolean JNICALL
Java_com_winlator_xenvironment_components_VortekRendererComponent_handleExtraDataRequest(JNIEnv *env,
                                                                                         jobject obj,
                                                                                         jlong contextPtr,
                                                                                         int requestId,
                                                                                         int requestLength) {
    return handleExtraDataRequest((VkContext*)contextPtr, requestId, requestLength);
}
