#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"

# Nombre exacto de tu asset maestro de 184.46 MB de tu foto
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== INICIANDO PURGA DE LOS 6 COMPONENTES DE PULSEAUDIO 13.0 ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS base preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN TOTAL DE LOS 6 RASTROS VIEJOS DE LA VERSIÓN 13.0
# ============================================================================
echo "-> Triturando de forma física los 6 componentes antiguos de PulseAudio..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/etc/pulse" || true

# Borramos de forma estricta los 6 archivos por su nombre plano en todo el árbol de directorios
find "$TMP_DIR" -name "libpulsecommon-13.0.so" -delete || true
find "$TMP_DIR" -name "libpulsecore-13.0.so" -delete || true
find "$TMP_DIR" -name "libpulse.so" -delete || true
find "$TMP_DIR" -name "libpulse.so.0" -delete || true
find "$TMP_DIR" -name "libpulseaudio.so" -delete || true
find "$TMP_DIR" -name "libltdl.so" -delete || true
find "$TMP_DIR" -name "libltdl.so.7" -delete || true
find "$TMP_DIR" -name "libsndfile.so" -delete || true
find "$TMP_DIR" -name "libsndfile.so.1" -delete || true

# ============================================================================
# 2. CONFIGURAR LA INFRAESTRUCTURA DE ENLACE DE ALSA AL CABLE UNIX NATIVO
# ============================================================================
echo "-> Sincronizando la estructura del cable de audio nativo..."
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

# Forzar las llaves estables dentro del registro de Windows del chroot
if [ -f "$TMP_DIR/home/xuser/.wine/user.reg" ]; then
  echo "-> Configurando las llaves del mezclador de audio en user.reg..."
  cat << 'EOF' >> "$TMP_DIR/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
fi

# ============================================================================
# 3. RECOMPRESIÓN SEGURA DE LA IMAGEFS EN ZSTD
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Fase DevOps terminada! Los 6 archivos antiguos han sido borrados de la RootFS ==="
