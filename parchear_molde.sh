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

echo "=== INICIANDO PURGA Y SUSTITUCIÓN SIMÉTRICA (6 DE 6) EN LA ROOTFS ==="
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
# 2. COLOCAR TUS 6 LIBRERÍAS DE LA VERSIÓN 17.0 EXACTAMENTE EN SU LUGAR (arm64-v8a)
# Seteamos tus binarios reales en la carpeta global /usr/lib/ para el chroot
# ============================================================================
echo "-> Sembrando tus 6 binarios reales de PulseAudio 17.0 en /usr/lib/ ..."
mkdir -p "$TMP_DIR/usr/lib"

# Copiamos de forma física tus 6 archivos exactos desde tu carpeta arm64-v8a del repositorio
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

# Enlaces simbólicos de compatibilidad requeridos por el enlazador de Wine en la raíz global
cd "$TMP_DIR/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

# Ajustamos permisos individuales de ejecución en Linux para tus 6 librerías reales (evita errores con symlinks)
echo "-> Calibrando permisos de ejecución en tus binarios..."
cd "$TMP_DIR/usr/lib"
chmod -f 0755 libpulse.so || true
chmod -f 0755 libpulsecommon-17.0.so || true
chmod -f 0755 libpulsecore-17.0.so || true
chmod -f 0755 libpulseaudio.so || true
chmod -f 0755 libltdl.so || true
chmod -f 0755 libsndfile.so || true
cd "$BASE_DIR"

# ============================================================================
# 3. REPARAR EL ARCHIVO DAEMON.CONF EN LA CARPETA QUE VISTE EN ZARCHIVER
# ============================================================================
echo "-> Reparando directivas de rutas en el archivo daemon.conf..."
daemon_conf_path=$(find "$TMP_DIR" -name "daemon.conf" -print -quit)
if [ -n "$daemon_conf_path" ]; then
  sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
fi

# ============================================================================
# 4. CONFIGURAR LA INFRAESTRUCTURA DE ENLACE DE ALSA AL CABLE UNIX NATIVO
# ============================================================================
echo "-> Sincronizando la pila ALSA al cable de comunicación Unix nativo..."
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
# 5. RECOMPRESIÓN SEGURA DE LA IMAGEFS EN ZSTD
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Sustitución simétrica completa en /usr/lib/ finalizada con éxito absoluto! ==="
