#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombres exactos de tus assets en el repositorio
ARCHIVO_MAESTRO="imagefs.tar.zst"
ARCHIVO_PULSE="pulseaudio.tzst"

TMP_IMAGEFS="$BASE_DIR/tmp_imagefs"
TMP_PULSE="$BASE_DIR/tmp_pulseaudio"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ] || [ ! -f "$ASSETS_DIR/$ARCHIVO_PULSE" ]; then
  echo "Error Crítico: No se localizó imagefs.tar.zst o pulseaudio.tzst en assets."
  exit 1
fi

echo "=== INICIANDO EXTRACCIÓN Y TRASVASE NATIVO DE MÓDULOS 17.0 ==="
mkdir -p "$TMP_IMAGEFS"
mkdir -p "$TMP_PULSE"

# 1. Desempaquetar la RootFS base de internet
echo "-> Desempaquetando la RootFS base (imagefs.tar.zst)..."
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_IMAGEFS"

# 2. Desempaquetar TU archivo pulseaudio.tzst personal para sacar tus 53 módulos reales
echo "-> Abriendo tu pulseaudio.tzst de assets para extraer tus módulos elásticos..."
tar -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_PULSE" -C "$TMP_PULSE"

# ============================================================================
# 3. FULMINACIÓN TOTAL DE LOS 6 RASTROS VIEJOS DE LA VERSIÓN 13.0
# ============================================================================
echo "-> Eliminando físicamente los 6 componentes antiguos de PulseAudio 13.0..."
rm -rf "$TMP_IMAGEFS/usr/lib/pulse-13.0" || true
rm -rf "$TMP_IMAGEFS/usr/local/lib/pulse-13.0" || true
rm -rf "$TMP_IMAGEFS/usr/etc/pulse" || true

find "$TMP_IMAGEFS" -name "libpulsecommon-13.0.so" -delete || true
find "$TMP_IMAGEFS" -name "libpulsecore-13.0.so" -delete || true
find "$TMP_IMAGEFS" -name "libpulse.so" -delete || true
find "$TMP_IMAGEFS" -name "libpulse.so.0" -delete || true
find "$TMP_IMAGEFS" -name "libpulseaudio.so" -delete || true
find "$TMP_IMAGEFS" -name "libltdl.so" -delete || true
find "$TMP_IMAGEFS" -name "libltdl.so.7" -delete || true
find "$TMP_IMAGEFS" -name "libsndfile.so" -delete || true
find "$TMP_IMAGEFS" -name "libsndfile.so.1" -delete || true

# ============================================================================
# 4. INYECTAR TUS 6 LIBRERÍAS DE JNILIBS EN LA RAÍZ GLOBAL (/usr/lib/)
# ============================================================================
echo "-> Sembrando tus 6 binarios reales de PulseAudio 17.0 de jniLibs en la RootFS..."
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_IMAGEFS/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_IMAGEFS/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_IMAGEFS/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_IMAGEFS/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_IMAGEFS/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_IMAGEFS/usr/lib/"

# Enlaces simbólicos reglamentarios requeridos en /usr/lib/ para Wine
cd "$TMP_IMAGEFS/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

# Ajustar permisos estrictamente en la raíz de librerías globales
chmod -f 0755 "$TMP_IMAGEFS/usr/lib"/libpulse*.so || true
chmod -f 0755 "$TMP_IMAGEFS/usr/lib"/libltdl*.so || true
chmod -f 0755 "$TMP_IMAGEFS/usr/lib"/libsndfile*.so || true

# ============================================================================
# 5. TRASLADAR TUS 53 MÓDULOS DESDE TU COMPRIMIDO A LA CARPETA DE LA ROOTFS
# ============================================================================
echo "-> Copiando tus módulos extraídos de pulseaudio.tzst hacia usr/lib/pulseaudio/modules/ ..."
mkdir -p "$TMP_IMAGEFS/usr/lib/pulseaudio/modules"

# Rastrear la subcarpeta de módulos dentro de tu pulseaudio.tzst extraído (modules/arm64, etc.)
RUTA_MODULOS_ORIGEN=$(find "$TMP_PULSE" -name "module-*.so" -print -quit)
if [ -n "$RUTA_MODULOS_ORIGEN" ]; then
  DIR_ORIGEN=$(dirname "$RUTA_MODULOS_ORIGEN")
  echo "  -> Detectada tu carpeta real de módulos en: $DIR_ORIGEN"
  cp -a "$DIR_ORIGEN"/*.so "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/" 2>/dev/null || true
else
  # Si están sueltos en la raíz de tu asset comprimido, los jala directamente
  cp -a "$TMP_PULSE"/*.so "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/" 2>/dev/null || true
fi

# Nos aseguramos de limpiar cualquier ejecutable core duplicado de la subcarpeta modules
rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libpulse"* || true
rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libltdl.so" || true
rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libsndfile.so" || true

# CORRECCIÓN DE RUTA EN PATCHELF: Sincroniza las identidades ELF estrictamente dentro de la carpeta modules
echo "-> Sincronizando identidades ELF modulares con patchelf..."
find "$TMP_IMAGEFS/usr/lib/pulseaudio/modules" -name "*.so" | while read -r mod_file; do
  patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --replace-needed libpulsecore-17.0.so libpulsecore-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
done

# CORRECCIÓN DE RUTA EN CHMOD: Permisos de ejecución de Linux aplicados directamente a tus módulos reales
chmod -f 0755 "$TMP_IMAGEFS/usr/lib/pulseaudio/modules"/*.so || true

# ============================================================================
# 6. REPARAR DAEMON.CONF Y ENLAZAR EL CABLE UNIX NATIVO PARA ANDROID 11
# ============================================================================
echo "-> Reparando directivas de rutas en el archivo daemon.conf..."
daemon_conf_path=$(find "$TMP_IMAGEFS" -name "daemon.conf" -print -quit)
if [ -n "$daemon_conf_path" ]; then
  sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
fi

echo "-> Sincronizando la estructura del cable de audio nativo..."
mkdir -p "$TMP_IMAGEFS/usr/etc/pulse"
cat << 'EOF' > "$TMP_IMAGEFS/usr/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
ctl.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
EOF

cat << 'EOF' > "$TMP_IMAGEFS/usr/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

if [ -f "$TMP_IMAGEFS/home/xuser/.wine/user.reg" ]; then
  cat << 'EOF' >> "$TMP_IMAGEFS/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
fi

# ============================================================================
# 7. RECOMPRESIÓN SEGURA DE LA IMAGEFS EN ZSTD
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_IMAGEFS"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

# Limpieza de las carpetas de trabajo temporales del runner
cd "$BASE_DIR"
rm -rf "$TMP_IMAGEFS" "$TMP_PULSE"
echo "=== ¡Sustitución y trasvase de módulos desde pulseaudio.tzst completado al 100%! ==="
