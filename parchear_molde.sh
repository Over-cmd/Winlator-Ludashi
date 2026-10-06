#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre exacto de tu asset maestro de 184.46 MB
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== INICIANDO PARCHEO EN LA RUTA QUIRÚRGICA: /usr/etc/ ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN TOTAL DE LOS 6 RASTROS VIEJOS 13.0
# ============================================================================
echo "-> Triturando de forma física los componentes antiguos de PulseAudio..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

find "$TMP_DIR" -name "libpulsecommon-13.0.so" -delete || true
find "$TMP_DIR" -name "libpulsecore-13.0.so" -delete || true
find "$TMP_DIR" -name "libpulse.so" -delete || true
find "$TMP_DIR" -name "libpulseaudio.so" -delete || true
find "$TMP_DIR" -name "libltdl.so" -delete || true
find "$TMP_DIR" -name "libsndfile.so" -delete || true

# ============================================================================
# 2. INYECTAR TUS 6 LIBRERÍAS DE LA VERSIÓN 17.0 DESDE TU CARPETA JNILIBS
# ============================================================================
echo "-> Sembrando tus 6 binarios reales 17.0 en /usr/lib/ ..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

chmod -f 0755 "$TMP_DIR/usr/lib"/lib*.so || true

# ============================================================================
# 3. RECONSTRUIR LA INFRAESTRUCTURA DE ENLACE ALSA Y RED POR SOCKET UNIX NATIVO (Android 11 Fix)
# ============================================================================
echo "-> Configurando la pila ALSA y el cliente en modo Socket Unix Nativo..."
mkdir -p "$TMP_DIR/usr/etc"
cat << 'EOF' > "$TMP_DIR/usr/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
ctl.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
EOF

mkdir -p "$TMP_DIR/usr/etc/pulse"
cat << 'EOF' > "$TMP_DIR/usr/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# Inyectamos las llaves nativas de sincronización dentro del registro de Windows del contenedor
if [ -f "$TMP_DIR/home/xuser/.wine/user.reg" ]; then
  echo "-> Forzando la activación de las llaves Unix de sonido en el registro de Wine..."
  cat << 'EOF' >> "$TMP_DIR/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM tram"="1"
EOF
fi

# ============================================================================
# 4. RECONSTRUIR ENLACE DE ALSA Y RED EN LA RUTA OFICIAL DE TU FOTO (/usr/etc/)
# ============================================================================
echo "-> Redirigiendo la pila ALSA y el cliente al puerto local loopback TCP..."
mkdir -p "$TMP_DIR/usr/etc"
cat << 'EOF' > "$TMP_DIR/usr/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "127.0.0.1:4713"
}
ctl.!default {
    type android_aserver
    socket "127.0.0.1:4713"
}
EOF

mkdir -p "$TMP_DIR/usr/etc/pulse"
cat << 'EOF' > "$TMP_DIR/usr/etc/pulse/client.conf"
default-server = tcp:127.0.0.1:4713
enable-shm = no
EOF

# Inyectamos las directivas TCP dentro del registro de Windows del contenedor
if [ -f "$TMP_DIR/home/xuser/.wine/user.reg" ]; then
  echo "-> Forzando la activación de las llaves TCP de sonido en el registro de Wine..."
  cat << 'EOF' >> "$TMP_DIR/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="tcp:127.0.0.1:4713"
"DisableSHM"="1"
EOF
fi

# ============================================================================
# 5. RECOMPRESIÓN SEGURA SIN ALTERAR SYMLINKS
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Sustitución completa! Los archivos en /usr/etc/ se han actualizado al 100% ==="
