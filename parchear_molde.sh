#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# ============================================================================
# 1. HACK QUIRÚRGICO DE CÓDIGO JAVA (Desarmar ImageFs.java e ImageFsInstaller.java)
# ============================================================================
echo "=== INTERCEPTANDO Y REESCRIBIENDO CLASES MAESTRAS DE IMAGEFS JAVA ==="

# Buscamos de forma recursiva cualquier archivo Java en la carpeta del entorno para parchear los strings rígidos
find "$BASE_DIR/app/src/main/java/com/winlator/cmod/xenvironment" -type f -name "*.java" | while read -r java_file; do
  if grep -qE "13\.0|pulse-13" "$java_file" 2>/dev/null; then
    echo "  -> Neutralizando firmas de PulseAudio 13.0 en: $(basename "$java_file")"
    # Reemplazar de forma estricta las referencias viejas por tus identidades reales de la versión 17.0
    sed -i 's/libpulsecommon-13.0.so/libpulsecommon-17.0.so/g' "$java_file" 2>/dev/null || true
    sed -i 's/libpulsecore-13.0.so/libpulsecore-17.0.so/g' "$java_file" 2>/dev/null || true
    sed -i 's/pulse-13.0/pulseaudio/g' "$java_file" 2>/dev/null || true
    sed -i 's/pulse-13/pulseaudio/g' "$java_file" 2>/dev/null || true
  fi
done

echo "  -> ¡Clases de inicialización Java parcheadas con éxito!"

# ============================================================================
# 2. FUNCIÓN INTERNA DE PURGA SUSTITUTIVA DE COMPRIMIDOS EN ASSETS
# ============================================================================
parchear_un_comprimido() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  # VALIDACIÓN DE FORMATO: Solo abrimos paquetes comprimidos reales (.tzst, .zst, .tar.zst)
  # Omitimos estrictamente tu 'pulseaudio.tzst' personal para respetar tus 53 módulos reales
  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]] || [ "$archivo" == "pulseaudio.tzst" ]; then
    return 0
  fi

  echo "=== ENTRANDO Y LIMPIANDO ASSET DE CONTENEDOR: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta los enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # Trituración física absoluta de directorios y binarios antiguos de la versión 13.0
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

  # Inyección de tus 6 librerías reales 17.0 en los moldes que contengan el sistema de archivos global
  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Sembrando tus 6 librerías limpias de la versión 17.0..."
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"

    # Enlaces simbólicos requeridos para forzar a Wine a apuntar a la versión 17.0
    cd "$tmp_dir/usr/lib"
    ln -sf libpulse.so libpulse.so.0 || true
    ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
    ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
    cd "$BASE_DIR"

    # Permisos individuales para evitar conflictos con symlinks rotos de gráficos
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

    # Inyección directa de las llaves en el registro local user.reg del molde
    if [ -f "$tmp_dir/home/xuser/.wine/user.reg" ]; then
      cat << 'EOF' >> "$tmp_dir/home/xuser/.wine/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    fi
  fi

  echo "  -> Recomprimiendo asset purgado: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 3. BUCLE DE BARRIDO TOTAL SOBRE LA CARPETA DE ASSETS
# ============================================================================
echo "=== INICIANDO BARRIDO GENERAL EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_comprimido "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps destructiva total completada con éxito! ==="
