#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre exacto de tu asset maestro de 184.46 MB de tu foto
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== CORRIGIENDO ENTORNO MULTIMEDIA: PARCHEO ESTABLE DE MÓDULOS ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS base preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN EXCLUSIVA DE COMPONENTES ANTIGUOS 13.0
# ============================================================================
echo "-> Triturando de forma física los componentes antiguos de PulseAudio..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

find "$TMP_DIR" -name "libpulsecommon-13.0.so" -delete || true
find "$TMP_DIR" -name "libpulsecore-13.0.so" -delete || true

# ============================================================================
# 2. SE QUEDAN TUS 6 LIBRERÍAS EXACTAMENTE DONDE YA FUNCIONABAN PERFECTO
# ============================================================================
echo "-> Asegurando tus 6 binarios reales 17.0 en /usr/lib/ ..."
mkdir -p "$TMP_DIR/usr/lib"
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

# Enlaces simbólicos de compatibilidad requeridos en la raíz de librerías
cd "$TMP_DIR/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

# ============================================================================
# 3. EL FIX DE COMPATIBILIDAD: INYECTAR LOS MÓDULOS PURGANDO LOS EXECUTABLES
# Sembramos tus complementos elásticos eliminando los cores para evitar el loop de Shutdown
# ============================================================================
echo "-> Estructurando subcarpeta de plugins elásticos nativos..."
mkdir -p "$TMP_DIR/usr/lib/pulseaudio/modules"
cp -a "$JNILIBS_DIR"/*.so "$TMP_DIR/usr/lib/pulseaudio/modules/" 2>/dev/null || true

echo "-> Purgando binarios principales de la subcarpeta de módulos para evitar el crash..."
# Borramos estrictamente los 6 archivos base de la subcarpeta de módulos para que queden solo los 53 plugins puros
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libpulse.so" || true
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libpulsecommon-17.0.so" || true
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libpulsecore-17.0.so" || true
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libpulseaudio.so" || true
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libltdl.so" || true
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libsndfile.so" || true

# Aplicar patchelf masivo exclusivamente a los módulos inyectados reales
echo "-> Corrigiendo identidades dinámicas de plugins con patchelf..."
find "$TMP_DIR/usr/lib/pulseaudio/modules" -name "*.so" | while read -r mod_file; do
  patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --replace-needed libpulsecore-17.0.so libpulsecore-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
done

chmod -f 0755 "$TMP_DIR/usr/lib"/lib*.so || true
chmod -f 0755 "$TMP_DIR/usr/lib/pulseaudio/modules"/*.so || true

# ============================================================================
# 4. REPARAR DAEMON.CONF Y CONFIGURAR TUBERÍA ALSA UNIX NATIVO PARA ANDROID 11
# ============================================================================
echo "-> Sincronizando configuraciones de arranque y cables de audio..."
daemon_conf_path=$(find "$TMP_DIR" -name "daemon.conf" -print -quit)
if [ -n "$daemon_conf_path" ]; then
  sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
fi

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
# 5. RECOMPRESIÓN SEGURA DE LA IMAGEFS
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Sustitución e inyección modular completada con éxito rotundo! ==="
