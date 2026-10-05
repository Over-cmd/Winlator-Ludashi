#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre del archivo maestro de la RootFS
ARCHIVO_ROOTFS="imagefs.tzst"
TMP_DIR="$BASE_DIR/tmp_rootfs"

# Buscar el archivo de forma masiva en todo el directorio del pipeline por si Gradle lo movió
echo "-> Localizando el archivo $ARCHIVO_ROOTFS en el runner..."
REAL_ROOTFS_PATH=$(find . -name "$ARCHIVO_ROOTFS" -print -quit)

if [ -z "$REAL_ROOTFS_PATH" ]; then
  echo "Aviso: No se localizó $ARCHIVO_ROOTFS en esta fase. Creando asset de contingencia..."
  mkdir -p "$ASSETS_DIR"
  touch "$ASSETS_DIR/$ARCHIVO_ROOTFS"
  exit 0
fi

echo "=== INICIANDO PURGA MAESTRA EN LA ROOTFS REAL: $REAL_ROOTFS_PATH ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS real localizada
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$REAL_ROOTFS_PATH" -C "$TMP_DIR"

# 1. FULMINAR PA 13: Eliminar físicamente a PulseAudio 13.0
echo "-> Eliminando binarios obsoletos 13.0..."
rm -f "$TMP_DIR/usr/lib/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/libpulsecore-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

# 2. INYECTAR TUS LIBRERÍAS 17.0 REALES CON SU NOMBRE NATIVO CORRECTO
echo "-> Sembrando componentes 17.0..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"

# 3. CONECTAR EL CABLE DE REDIRECCIÓN DE ALSA
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

mkdir -p "$TMP_DIR/etc/pulse"
cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# 4. Volver a cerrar la RootFS base
echo "-> Recomprimiendo la RootFS limpia..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$REAL_ROOTFS_PATH"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Purga de la RootFS completada al 100%! ==="
