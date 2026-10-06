#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# ============================================================================
# 1. EL HACK ANTIDESCARGAS: INTERCEPTAR EL INSTALADOR JAVA (ImageFsInstaller.java)
# ============================================================================
echo "===INYECTANDO FILTRO ANTIDESCARGAS EN EL INSTALADOR JAVA ==="
INSTALLER_FILE="app/src/main/java/com/winlator/cmod/xenvironment/ImageFsInstaller.java"

if [ -f "$INSTALLER_FILE" ]; then
  echo "  -> ¡Modificando ImageFsInstaller.java para bloquear la versión 13 de internet!"
  
  # Reemplazar de forma estricta los strings viejos por tu versión 17 en el código de Java
  sed -i 's/libpulsecommon-13.0.so/libpulsecommon-17.0.so/g' "$INSTALLER_FILE" 2>/dev/null || true
  sed -i 's/libpulsecore-13.0.so/libpulsecore-17.0.so/g' "$INSTALLER_FILE" 2>/dev/null || true
  sed -i 's/pulse-13.0/pulseaudio/g' "$INSTALLER_FILE" 2>/dev/null || true
  sed -i 's/pulse-13/pulseaudio/g' "$INSTALLER_FILE" 2>/dev/null || true
  
  echo "  -> ¡ImageFsInstaller.java blindado con éxito contra descargas externas!"
else
  # Búsqueda elástica en todo el subdirectorio de Java por si acaso
  find . -name "ImageFsInstaller.java" -exec sed -i 's/libpulsecommon-13.0.so/libpulsecommon-17.0.so/g' {} + || true
  find . -name "ImageFsInstaller.java" -exec sed -i 's/libpulsecore-13.0.so/libpulsecore-17.0.so/g' {} + || true
fi

# Hacer un escaneo preventivo en el archivo ImageFs.java por si retiene rutas rígidas de extracción
find "$BASE_DIR/app/src/main/java/com/winlator/cmod/xenvironment" -type f -name "ImageFs.java" | while read -r java_file; do
  sed -i 's/libpulsecommon-13.0.so/libpulsecommon-17.0.so/g' "$java_file" 2>/dev/null || true
  sed -i 's/libpulsecore-13.0.so/libpulsecore-17.0.so/g' "$java_file" 2>/dev/null || true
done

# ============================================================================
# 2. FUNCIÓN INTERNA DE PURGA EN LOS COMPRIMIDOS LOCALES DE ASSETS
# ============================================================================
parchear_un_comprimido() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  # VALIDACIÓN: Solo abrimos paquetes comprimidos reales (.tzst, .zst, .tar.zst)
  # Omitimos estrictamente tu 'pulseaudio.tzst' personal para respetar tus 53 módulos subidos
  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]] || [ "$archivo" == "pulseaudio.tzst" ]; then
    return 0
  fi

  echo "=== LIMPIANDO ASSET LOCAL: $archivo ==="
  mkdir -p "$tmp_dir"
  
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # Trituración física absoluta de directorios antiguos 13.0 en las plantillas de fábrica
  rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/etc/pulse" || true
  rm -rf "$tmp_dir/etc/pulse" || true

  find "$tmp_dir" -name "libpulsecommon-13.0.so" -delete || true
  find "$tmp_dir" -name "libpulsecore-13.0.so" -delete || true
  find "$tmp_dir" -name "libpulse.so" -delete || true
  find "$tmp_dir" -name "libpulse.so.0" -delete || true
  find "$tmp_dir" -name "libpulseaudio.so" -delete || true
  find "$tmp_dir" -name "libltdl.so" -delete || true
  find "$tmp_dir" -name "libltdl.so.7" -delete || true
  find "$tmp_dir" -name "libsndfile.so" -delete || true
  find "$tmp_dir" -name "libsndfile.so.1" -delete || true

  # Inyección limpia de tus 6 librerías reales 17.0 en los moldes con sistema de archivos
  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Sediando tus 6 librerías de la versión 17.0..."
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"

    cd "$tmp_dir/usr/lib"
    ln -sf libpulse.so libpulse.so.0 || true
    ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
    ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
    cd "$BASE_DIR"

    cd "$tmp_dir/usr/lib"
    chmod -f 0755 libpulse.so || true
    chmod -f 0755 libpulsecommon-17.0.so || true
    chmod -f 0755 libpulsecore-17.0.so || true
    chmod -f 0755 libpulseaudio.so || true
    chmod -f 0755 libltdl.so || true
    chmod -f 0755 libsndfile.so || true
    cd "$BASE_DIR"

    # Corregir las rutas muertas de las capturas de AkelPad en los archivos de configuración
    find "$tmp_dir" -name "default.pa" -o -name "daemon.conf" -o -name "client.conf" | while read -r config_file; do
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
    done
  fi

  echo "  -> Recomprimiendo asset purgado: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 3. BUCLE DE BARRIDO TOTAL SOBRE LA CARPETA DE ASSETS LOCALES
# ============================================================================
echo "=== INICIANDO BARRIDO GENERAL EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_comprimido "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps destructiva total completada con éxito! ==="
