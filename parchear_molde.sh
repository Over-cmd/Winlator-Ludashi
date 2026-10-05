#!/usr/bin/env bash
set -euo pipefail

echo "=== Iniciando la reconstrucción de la pila ALSA/PulseAudio en el molde ==="
BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"
TMP_DIR="$BASE_DIR/tmp_pattern"

# 1. Crear directorio temporal y desempaquetar el molde de tus assets
mkdir -p "$TMP_DIR"
tar -I 'zstd -d' -xf "$ASSETS_DIR/container_pattern_common.tzst" -C "$TMP_DIR"

# 2. Purgar físicamente las librerías obsoletas de la versión 13.0
echo "-> Eliminando residuos obsoletos del molde..."
rm -f "$TMP_DIR/usr/lib/libpulsecommon-13.0.so"
rm -f "$TMP_DIR/usr/lib/libpulsecore-13.0.so"
rm -f "$TMP_DIR/home/xuser/libpulse"* || true

# 3. Inyectar las 3 librerías compartidas (Ya perfectamente parcheadas por patchelf)
echo "-> Inyectando componentes de PulseAudio 17.0 a /usr/lib/ ..."
mkdir -p "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"

# 4. RECONSTRUIR EL ARCHIVO ASOUND.CONF DE ALSA
echo "-> Creando archivo de configuración maestro asound.conf..."
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

# 5. CONFIGURAR CLIENT.CONF GLOBAL
echo "-> Configurando directivas del cliente de audio para PA 17.0..."
mkdir -p "$TMP_DIR/etc/pulse"
cat << 'EOF' > "$TMP_DIR/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# 6. Volver a cerrar el molde con máxima compresión ZSTD usando todos los hilos
echo "-> Cerrando y recomprimiendo container_pattern_common.tzst..."
cd "$TMP_DIR"
tar -cvf - * | zstd -19 -T0 > "$ASSETS_DIR/container_pattern_common.tzst"

# 7. Limpieza de residuos
cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Pila de ALSA, asound.conf y librerías parcheadas listas en el molde! ==="
