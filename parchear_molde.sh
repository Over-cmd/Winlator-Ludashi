#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Nombre exacto del asset maestro que se descarga en el paso de Gradle
ARCHIVO_MAESTRO="imagefs.tar.zst"
TMP_DIR="$BASE_DIR/tmp_imagefs"

if [ ! -f "$ASSETS_DIR/$ARCHIVO_MAESTRO" ]; then
  echo "Error Crítico: No se localizó el archivo $ARCHIVO_MAESTRO en la carpeta de assets."
  exit 1
fi

echo "=== INICIANDO PURGA CONTROLADA REPETIDA (MÉTODO SIN NÚMEROS) ==="
mkdir -p "$TMP_DIR"

# Desempaquetar la RootFS descargada de internet preservando los enlaces simbólicos de Linux
tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$ARCHIVO_MAESTRO" -C "$TMP_DIR"

# ============================================================================
# 1. TRITURACIÓN DE RESIDUOS ANTERIORES
# ============================================================================
echo "-> Eliminando directorios antiguos de la versión 13.0..."
rm -rf "$TMP_DIR/usr/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/local/lib/pulse-13.0" || true
rm -rf "$TMP_DIR/usr/etc/pulse" || true
rm -rf "$TMP_DIR/etc/pulse" || true

# ============================================================================
# 2. SEMBRAR TUS 6 LIBRERÍAS DE JNILIBS Y CREAR LOS REEMPLAZOS SIN NÚMERO
# ============================================================================
echo "-> Sembrando tus 6 binarios reales en /usr/lib/..."
mkdir -p "$TMP_DIR/usr/lib"

cp -a "$JNILIBS_DIR"/libpulse.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libpulseaudio.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libltdl.so "$TMP_DIR/usr/lib/"
cp -a "$JNILIBS_DIR"/libsndfile.so "$TMP_DIR/usr/lib/"

# LA JUGADA MAESTRA HISTÓRICA: Forzamos que los nombres antiguos apunten a tus archivos planos reales.
# Así, cuando Wine o la imagen busquen la versión 13, cargarán de golpe tus librerías 17 libres de números.
cd "$TMP_DIR/usr/lib"
ln -sf libpulse.so libpulse.so.0 || true
ln -sf libpulsecommon-17.0.so libpulsecommon.so || true
ln -sf libpulsecore-17.0.so libpulsecore.so || true

# Sobrescribir de forma física los nombres con el string '-13.0.so' para que mueran para siempre
ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
cd "$BASE_DIR"

# Ajustar permisos individuales de Linux sobre tus binarios
cd "$TMP_DIR/usr/lib"
chmod -f 0755 libpulse.so || true
chmod -f 0755 libpulsecommon-17.0.so || true
chmod -f 0755 libpulsecore-17.0.so || true
chmod -f 0755 libpulseaudio.so || true
chmod -f 0755 libltdl.so || true
chmod -f 0755 libsndfile.so || true
cd "$BASE_DIR"

# ============================================================================
# 3. INTERCEPCIÓN EN CALIENTE DE LAS RUTAS INTERNAS (AkelPad Fix)
# ============================================================================
echo "-> Limpiando rutas muertas de com.winlator.cmod en los scripts planos..."
find "$TMP_DIR" -name "default.pa" -o -name "daemon.conf" -o -name "client.conf" | while read -r config_file; do
  sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
done

# ============================================================================
# 4. RECOMPRESIÓN SEGURA DE LA IMAGEFS EN ZSTD MAESTRO
# ============================================================================
echo "-> Volviendo a cerrar $ARCHIVO_MAESTRO con máxima compresión ZSTD..."
cd "$TMP_DIR"
find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$ARCHIVO_MAESTRO"

cd "$BASE_DIR"
rm -rf "$TMP_DIR"
echo "=== ¡Fase DevOps completada al 100% con el método de archivos sin número! ==="
