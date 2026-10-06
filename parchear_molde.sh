#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# RUTA EXACTA DE TU CAPTURA DE PANTALLA
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== INICIANDO PURGA QUIRÚRGICA EN LA ROOTFS REAL: $ARCHIVO_MAESTRO ==="
mkdir -p "$TMP_DIR"

# 1. Desempaquetar la RootFS de tu foto preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# 2. FULMINAR VERSIÓN 13.0: Borramos de forma física y radical los archivos viejos que te bloqueaban el audio
echo "  -> Triturando binarios obsoletos de la versión 13.0..."
find "$TMP_DIR" -name "*13.0.so" -delete || true
rm -f "$TMP_DIR/usr/lib/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/libpulsecore-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

# 3. INYECTAR TU VERSIÓN ELÁSTICA DE PULSEAUDIO 17.0
echo "  -> Sediando tus componentes legítimos 17.0 en las carpetas globales del sistema..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"

# 4. RECONSTRUIR EL ARCHIVO ASOUND.CONF DE ALSA (Para forzar a Wine a salir de None)
echo "  -> Conectando el cable maestro /etc/asound.conf..."
mkdir -p "$TMP_DIR/etc"
cat << 'EOF' > "$TMP_DIR/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
ctl.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
EOF

# 5. CONFIGURAR CLIENT.CONF DEL ENTORNO GLOBAL
mkdir -p "$TMP_DIR/etc/pulse"
cat << 'EOF' > "$TMP_DIR/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# 6. Volver a cerrar la RootFS con máxima compresión ZSTD preservando la estructura nativa intacta
echo "  -> Recomprimiendo $ARCHIVO_MAESTRO en formato doble tar.zst legítimo..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

# Limpieza de temporales del runner
cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Fase DevOps completada! imagefs.tar.zst ha sido purgado y blindado con éxito ==="
