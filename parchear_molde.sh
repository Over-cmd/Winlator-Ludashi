#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# ============================================================================
# 1. HACK ANTIDESCARGAS EN GRADLE Y CMAKE (Bloquear la sobrescritura en la nube)
# ============================================================================
echo "=== BLOQUEANDO DESCARGAS AUTOMÁTICAS DE LA ROOTFS VIEJA EN GRADLE/CMAKE ==="

# Buscamos scripts de Gradle, CMake o Bash que puedan estar descargando la RootFS de internet
find "$BASE_DIR" -type f \( -name "build.gradle" -o -name "CMakeLists.txt" -o -name "*.sh" -o -name "*.yml" \) | while read -r config_file; do
  # Si el archivo intenta descargar un imagefs o pulseaudio antiguo de un servidor externo, lo neutralizamos
  if grep -qE "imagefs.*zst|pulseaudio.*tzst" "$config_file" 2>/dev/null; then
    echo "  -> Revisando lógica de empaquetado en: $(basename "$config_file")"
    # Forzar a que CMake o Gradle ignoren comandos de descarga externa (wget/curl) sobre el asset maestro
    sed -i 's/downloadImageFs/echo "Saltando descarga externa"/g' "$config_file" 2>/dev/null || true
    sed -i 's/downloadPulseAudio/echo "Saltando descarga externa"/g' "$config_file" 2>/dev/null || true
  fi
done

# ============================================================================
# 2. PARCHEO DE LAS CLASES DE INICIALIZACIÓN JAVA
# ============================================================================
echo "=== PURGANDO TEXTOS RÍGIDOS 13.0 EN CLASES JAVA ==="
find "$BASE_DIR/app/src/main/java/com/winlator/cmod/xenvironment" -type f -name "*.java" | while read -r java_file; do
  if grep -qE "13\.0|pulse-13" "$java_file" 2>/dev/null; then
    echo "  -> Neutralizando firmas de PulseAudio 13.0 en: $(basename "$java_file")"
    sed -i 's/libpulsecommon-13.0.so/libpulsecommon-17.0.so/g' "$java_file" 2>/dev/null || true
    sed -i 's/libpulsecore-13.0.so/libpulsecore-17.0.so/g' "$java_file" 2>/dev/null || true
    sed -i 's/pulse-13.0/pulseaudio/g' "$java_file" 2>/dev/null || true
    sed -i 's/pulse-13/pulseaudio/g' "$java_file" 2>/dev/null || true
  fi
done

# ============================================================================
# 3. FUNCIÓN DE PURGA EXTREMA EN LOS COMPRIMIDOS LOCALES DE ASSETS
# ============================================================================
parchear_un_comprimido() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]] || [ "$archivo" == "pulseaudio.tzst" ]; then
    return 0
  fi

  echo "=== LIMPIANDO COMPRIMIDO LOCAL: $archivo ==="
  mkdir -p "$tmp_dir"
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # Borrado físico absoluto de la versión 13.0
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

  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Inyectando tus 6 librerías 17.0 de reemplazo..."
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

    find "$tmp_dir" -name "default.pa" -o -name "daemon.conf" -o -name "client.conf" | while read -r config_file; do
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
    done
  fi

  echo "  -> Recomprimiendo asset: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 4. BUCLE DE BARRIDO GLOBAL SOBRE ASSETS COMPRIMIDOS
# ============================================================================
echo "=== INICIANDO BARRIDO GENERAL EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_comprimido "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps destructiva total completada con éxito! ==="
