#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre exacto de tu asset maestro de 184.46 MB de tus capturas
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== INICIANDO PURGA Y REDIRECCIÓN INTERNA EN LA ROOTFS ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS base original preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN TOTAL DE LOS 6 RASTROS VIEJOS DE LA VERSIÓN 13.0
# ============================================================================
echo "-> Triturando de forma física los componentes antiguos e hilos de PulseAudio 13..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

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
# 2. COLOCAR TUS 6 LIBRERÍAS DE LA VERSIÓN 17.0 EXACTAMENTE EN SU LUGAR (usr/lib/)
# ============================================================================
echo "-> Sembrando tus 6 binarios reales de PulseAudio 17.0 en /usr/lib/ ..."
mkdir -p "$TMP_DIR/usr/lib"

cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

cd "$TMP_DIR/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

cd "$TMP_DIR/usr/lib"
chmod -f 0755 libpulse.so || true
chmod -f 0755 libpulsecommon-17.0.so || true
chmod -f 0755 libpulsecore-17.0.so || true
chmod -f 0755 libpulseaudio.so || true
chmod -f 0755 libltdl.so || true
chmod -f 0755 libsndfile.so || true
cd "$BASE_DIR"

# ============================================================================
# 3. INTERCEPCIÓN Y LIMPIEZA DE LAS RUTAS RÍGIDAS DE TUS CAPTURAS (AkelPad Fix)
# ============================================================================
echo "-> Corrigiendo en caliente los archivos default.pa y daemon.conf de tus fotos..."
find "$TMP_DIR" -name "default.pa" -o -name "daemon.conf" | while read -r config_file; do
  echo "  -> Dinamizando archivo: $config_file"
  # Descomentar directivas rígidas muertas
  sed -i 's/; default-script-file =/default-script-file =/g' "$config_file" 2>/dev/null || true
  # Purgar por completo el prefijo de paquete com.winlator.cmod de raíz en todo el documento
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
done

# ============================================================================
# 4. CONFIGURAR LA INFRAESTRUCTURA DE ENLACE DE ALSA AL CABLE UNIX NATIVO
# ============================================================================
echo "-> Sincronizando el cableado de la pila ALSA en las rutas de tus imágenes..."

# Carpeta 1 (/etc/)
mkdir -p "$TMP_DIR/etc/pulse"
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
cat << 'EOF' > "$TMP_DIR/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

# Carpeta 2 (/usr/etc/)
mkdir -p "$TMP_DIR/usr/etc/pulse"
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
cat << 'EOF' > "$TMP_DIR/usr/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

if [ -f "$TMP_DIR/home/xuser/.wine/user.reg" ]; then
  cat << 'EOF' >> "$TMP_DIR/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
fi

# ============================================================================
# 5. RECOMPRESIÓN SEGURA DE LA IMAGEFS EN FORMATO TAR.ZST MAESTRO
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Sustitución completa en limpio finalizada con éxito absoluto! ==="
