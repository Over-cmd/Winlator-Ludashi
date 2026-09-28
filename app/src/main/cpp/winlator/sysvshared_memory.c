#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/ipc.h>
#include <sys/syscall.h>
#include <jni.h>
#include <android/log.h>
#include <android/sharedmem.h> // 🚀 CRÍTICO: Necesario para la API ASharedMemory en Android moderno

#define __u32 uint32_t
#include <linux/ashmem.h>

#define printf(...) __android_log_print(ANDROID_LOG_DEBUG, "System.out", __VA_ARGS__);

static int ashmemCreateRegion(const char* name, int64_t size) {
    // 🚀 EL SECRETO ACÚSTICO DE ALEXVORXX PARA MALI:
    // Si el teléfono corre con Android 8.0+ (API 26), usamos la memoria compartida por hardware nativa.
    // Esto evita el nodo obsoleto /dev/ashmem (bloqueado por Google en Android 11+), permitiendo que Wine
    // y PulseAudio escriban y lean datos en el mismo bloque físico de la RAM instantáneamente y sin retrasos.
#if __ANDROID_API__ >= 26
    int fd = ASharedMemory_create(name, size);
    if (fd < 0) return -1;
    return fd;
#else
    // Plan de emergencia plano solo para teléfonos muy antiguos
    int fd = open("/dev/ashmem", O_RDWR);
    if (fd < 0) return -1;

    char nameBuffer[ASHMEM_NAME_LEN] = {0};
    strncpy(nameBuffer, name, sizeof(nameBuffer));
    nameBuffer[sizeof(nameBuffer) - 1] = 0;

    int ret = ioctl(fd, ASHMEM_SET_NAME, nameBuffer);
    if (ret < 0) goto error;

    ret = ioctl(fd, ASHMEM_SET_SIZE, size);
    if (ret < 0) goto error;

    return fd;
error:
    close(fd);
    return -1;
#endif
}

static int memfd_create(const char *name, unsigned int flags) {
#ifdef __NR_memfd_create
    return syscall(__NR_memfd_create, name, flags);
#else
    return -1;
#endif
}

JNIEXPORT jint JNICALL
Java_com_winlator_cmod_sysvshm_SysVSharedMemory_ashmemCreateRegion(JNIEnv *env, jobject obj, jint index,
                                                              jlong size) {
    char name[32];
    sprintf(name, "sysvshm-%d", index);
    return ashmemCreateRegion(name, size);
}

JNIEXPORT jobject JNICALL
Java_com_winlator_cmod_sysvshm_SysVSharedMemory_mapSHMSegment(JNIEnv *env, jobject obj, jint fd, jlong size, jint offset, jboolean readonly) {
    char *data = mmap(NULL, size, readonly ? PROT_READ : PROT_WRITE | PROT_READ, MAP_SHARED, fd, offset);
    if (data == MAP_FAILED) return NULL;
    return (*env)->NewDirectByteBuffer(env, data, size);
}

JNIEXPORT void JNICALL
Java_com_winlator_cmod_sysvshm_SysVSharedMemory_unmapSHMSegment(JNIEnv *env, jobject obj, jobject data,
                                                           jlong size) {
    char *dataAddr = (*env)->GetDirectBufferAddress(env, data);
    munmap(dataAddr, size);
}

JNIEXPORT jint JNICALL
Java_com_winlator_cmod_sysvshm_SysVSharedMemory_createMemoryFd(JNIEnv *env, jclass obj, jstring name,
                                                          jint size) {
    const char *namePtr = (*env)->GetStringUTFChars(env, name, 0);

    int fd = memfd_create(namePtr, MFD_ALLOW_SEALING);
    (*env)->ReleaseStringUTFChars(env, name, namePtr);

    if (fd < 0) return -1;

    int res = ftruncate(fd, size);
    if (res < 0) {
        close(fd);
        return -1;
    }

    return fd;
}
