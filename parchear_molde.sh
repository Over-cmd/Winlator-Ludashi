#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre del archivo maestro de la RootFS descargado por Gradle
ARCHIVO_ROOTFS="imagefs.tzst"
TMP_DIR="$BASE_DIR/tmp_rootfs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_ROOTFS" ]; then
  echo "Error Crítico: No se encontró el archivo $ARCHIVO_ROOTFS en assets. Abortando."
  exit 1
fi

echo "=== INICIANDO PURGA MAESTRA EN LA ROOTFS: $ARCHIVO_ROOTFS ==="
mkdir -p "$TMP_DIR"

# 1. Desempaquetar la RootFS real preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_ROOTFS" -C "$TMP_DIR"

# 2. FULMINAR PA 13: Eliminar de forma física y radical todas las librerías viejas de la RootFS
echo "-> Eliminando físicamente los binarios obsoletos de la versión 13.0..."
rm -f "$TMP_DIR/usr/lib/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/libpulsecore-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
rm -f "$TMP_DIR/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

# 3. INYECTAR TUS COMPONENTES REALES 17.0 CON SU NOMBRE NATIVO CORRECTO
echo "-> Inyectando tus librerías de PulseAudio 17.0 renombradas a las carpetas globales..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"

# 4. RECONSTRUIR EL ARCHIVO MAESTRO DE REDIRECCIÓN DE ALSA (Para quitar Driver: None)
echo "-> Creando archivo maestro /etc/asound.conf en el núcleo de Linux..."
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

# 5. CONFIGURAR CLIENT.CONF MAESTRO PARA LA VERSIÓN 17.0
echo "-> Configurando directivas globales de red en /etc/pulse/client.conf..."
mkdir -p "$TMP_DIR/etc/pulse"
cat << 'EOF' > "$TMP_DIR/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# 6. PARCHEAR EL REGISTRO MODO DE PROTECCIÓN SI WINE TIENE UN REGISTRO PRECOMPILADO
if [ -f "$TMP_DIR/home/xuser/.wine/user.reg" ]; then
  echo "-> Forzando la activación de los drivers en el registro integrado..."
  cat << 'EOF' >> "$TMP_DIR/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
fi

# 7. Volver a cerrar la RootFS base con máxima compresión ZSTD preservando enlaces simbólicos
echo "-> Recomprimiendo imagefs.tzst sin alterar los symlinks nativos del sistema operativo..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_ROOTFS"

# Limpieza de residuos en el runner
cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡RootFS imagefs.tzst purgada y reestructurada con PulseAudio 17.0 con éxito absoluto! ==="
