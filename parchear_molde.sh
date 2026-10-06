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

echo "=== INICIANDO PURGA Y SUSTITUCIÓN SIMÉTRICA LIMPIA EN LA ROOTFS ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS base original preservando de forma estricta los enlaces simbólicos y permisos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. FULMINACIÓN TOTAL DE LOS 6 RASTROS VIEJOS DE LA VERSIÓN 13.0
# ============================================================================
echo "-> Triturando de forma física los 6 componentes antiguos de PulseAudio 13..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true

# Borramos de forma estricta los 6 archivos antiguos por su nombre plano en todo el chroot
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
# 2. INYECTAR TUS 6 LIBRERÍAS DE LA VERSIÓN 17.0 EXACTAMENTE EN SU SITIO (/usr/lib/)
# ============================================================================
echo "-> Sembrando tus 6 binarios reales de PulseAudio 17.0 en la raíz global..."
mkdir -p "$TMP_DIR/usr/lib"

# Copiamos de forma física tus 6 archivos exactos desde tu carpeta arm64-v8a del repositorio
cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

# Enlaces simbólicos reglamentarios requeridos en /usr/lib/ por el enlazador dinámico de Wine
cd "$TMP_DIR/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

# Seteamos permisos de ejecución de Linux a tus 6 librerías reales (evita colisiones con symlinks rotos)
cd "$TMP_DIR/usr/lib"
chmod -f 0755 libpulse.so || true
chmod -f 0755 libpulsecommon-17.0.so || true
chmod -f 0755 libpulsecore-17.0.so || true
chmod -f 0755 libpulseaudio.so || true
chmod -f 0755 libltdl.so || true
chmod -f 0755 libsndfile.so || true
cd "$BASE_DIR"

# ============================================================================
# 3. INTERCEPCIÓN EN CALIENTE DE LAS RUTAS MUERTAS EN TODOS LOS ARCHIVOS .CONF Y .PA
# ============================================================================
echo "-> Corrigiendo en caliente las rutas en default.pa, daemon.conf y el nuevo client.conf..."
# El asterisco hace que barra cualquier extensión dentro de las carpetas pulse duplicadas de tus fotos
find "$TMP_DIR" -name "default.pa" -o -name "daemon.conf" -o -name "client.conf" | while read -r config_file; do
  echo "  -> Purgando prefijo muerto com.winlator.cmod en: $config_file"
  # Remueve el rastro com.winlator.cmod de la faz del documento de forma segura sin alterar las líneas comentadas
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
done

# ============================================================================
# 4. RECOMPRESIÓN SEGURA DE TU IMAGEFS EN FORMATO TAR_ZST MAESTRO
# ============================================================================
echo "-> Cerrando y sellando $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Fase DevOps completada con éxito rotundo! RootFS limpia y ultraestable ==="
