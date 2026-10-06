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

echo "=== INICIANDO PARCHEO GLOBAL Y RELLENO DE MÓDULOS EN LA ROOTFS ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS base preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN TOTAL DE LOS COMPONENTES ANTIGUOS 13.0
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

# ============================================================================
# 3. EL GOLPE DE GRACIA (INYECTAR LOS 53 MÓDULOS EN LA ROOTFS GLOBAL)
# Sembramos tus módulos en el directorio de sistema que lee el binario compilado
# ============================================================================
echo "-> Creando el directorio de módulos e inyectando los 53 complementos .so..."
mkdir -p "$TMP_DIR/usr/lib/pulseaudio/modules"
cp -a "$JNILIBS_DIR"/*.so "$TMP_DIR/usr/lib/pulseaudio/modules/" 2>/dev/null || true

# Limpiamos las librerías base de la carpeta modules para dejar solo los plugins puros
rm -f "$TMP_DIR/usr/lib/pulseaudio/modules/libpulse"* "$TMP_DIR/usr/lib/pulseaudio/modules/libltdl.so" "$TMP_DIR/usr/lib/pulseaudio/modules/libsndfile.so" || true

# Aplicar patchelf masivo a tus archivos inyectados en la RootFS para reparar cabeceras ELF
echo "-> Corrigiendo identidades dinámicas con patchelf..."
find "$TMP_DIR" -name "*.so" | while read -r mod_file; do
  patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --replace-needed libpulsecore-17.0.so libpulsecore-17.0.so "$mod_file" 2>/dev/null || true
  patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
done

chmod -f 0755 "$TMP_DIR/usr/lib"/lib*.so || true
chmod -f 0755 "$TMP_DIR/usr/lib/pulseaudio/modules"/*.so || true

# ============================================================================
# 4. REPARAR EL ARCHIVO DAEMON.CONF EN LA RUTA DE TU FOTO (/usr/etc/pulse/)
# ============================================================================
echo "-> Interceptando y dinamizando el archivo daemon.conf..."
local daemon_conf_path=$(find "$TMP_DIR" -name "daemon.conf" -print -quit)
if [ -n "$daemon_conf_path" ]; then
  sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
fi

# ============================================================================
# 5. RECONSTRUIR EL ARCHIVO DE ENLACE DE ALSA AL CABLE UNIX NATIVO EN ANDROID 11
# ============================================================================
echo "-> Sincronizando la pila ALSA al cable de comunicación Unix nativo..."
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

# Forzar las llaves Unix en el registro de Windows del contenedor
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
# 6. RECOMPRESIÓN SEGURA SIN ALTERAR SYMLINKS
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Sustitución completa e inyección Unix terminada con éxito! ==="
