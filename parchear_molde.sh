#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

ARCHIVO_ROOTFS="imagefs.tzst"
TMP_DIR="$BASE_DIR/tmp_rootfs"

echo "-> Localizando el archivo $ARCHIVO_ROOTFS real descargado en el runner..."

# Buscamos de forma masiva todos los archivos imagefs.tzst y filtramos para quedarnos 
# exclusivamente con el archivo real (el que pesa más de 50MB), ignorando los HTML corruptos de 0KB.
REAL_ROOTFS_PATH=""
while read -r encontrado; do
  if [ -f "$encontrado" ] && [ "$(stat -c%s "$encontrado")" -gt 10000000 ]; then
    REAL_ROOTFS_PATH="$encontrado"
    break
  fi
done < <(find . -name "$ARCHIVO_ROOTFS")

if [ -z "$REAL_ROOTFS_PATH" ]; then
  echo "Aviso: No se localizó una RootFS válida en esta fase o Gradle usa otra extensión. Saltando parcheo para no romper el APK."
  exit 0
fi

echo "=== INICIANDO PURGA MAESTRA EN LA ROOTFS REAL: $REAL_ROOTFS_PATH ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS real localizada preservando los enlaces simbólicos nativos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$REAL_ROOTFS_PATH" -C "$TMP_DIR"

# 1. FULMINAR PA 13: Eliminar de forma física y radical todas las librerías viejas de la RootFS
echo "-> Eliminando binarios obsoletos 13.0..."
rm -f "$TMP_DIR/usr/lib/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/libpulsecore-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

# 2. INYECTAR TUS COMPONENTES REALES 17.0 CON SU NOMBRE NATIVO CORRECTO
echo "-> Sembrando componentes 17.0 del repositorio..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"

# 3. CONECTAR EL CABLE DE REDIRECCIÓN DE ALSA
echo "-> Configurando archivo maestro /etc/asound.conf..."
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
cat << 'EOF' > "$TMP_DIR/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# 4. Volver a cerrar la RootFS base con máxima compresión ZSTD preservando enlaces simbólicos
echo "-> Recomprimiendo la RootFS limpia..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$REAL_ROOTFS_PATH"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Purga de la RootFS completa y sin errores de formato! ==="
