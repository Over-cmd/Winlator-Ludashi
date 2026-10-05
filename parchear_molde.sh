#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

parchear_un_asset() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  echo "=== DEFENDIENDO PULSEAUDIO 17.0 EN: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # ============================================================================
  # 1. TRITURACIÓN RADICAL DE LA VERSIÓN 13.0 (Eliminación forzada)
  # ============================================================================
  echo "  -> Purgando binarios y scripts residuales de la versión 13.0..."
  find "$tmp_dir" -name "*13.0.so" -delete || true
  rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
  
  # Hackear cualquier script interno de instalación en la RootFS para que no intente buscar la versión 13
  find "$tmp_dir" -name "*.sh" -o -name "*.py" | while read -r script_file; do
    sed -i 's/13.0/17.0/g' "$script_file" 2>/dev/null || true
    sed -i 's/pulse-13.0/pulseaudio/g' "$script_file" 2>/dev/null || true
  done

  # ============================================================================
  # 2. INYECTAR TU VERSIÓN 17.0 ELÁSTICA CON TUS COMPONENTES DE JNILIBS
  # ============================================================================
  if [ -d "$tmp_dir/usr/lib" ] || [ "$archivo" == "pulseaudio.tzst" ]; then
    echo "  -> Inyectando tus componentes de la versión 17.0..."
    local destino_lib="$tmp_dir/usr/lib"
    [ "$archivo" == "pulseaudio.tzst" ] && destino_lib="$tmp_dir"
    
    mkdir -p "$destino_lib"
    cp -a "$JNILIBS_DIR"/libpulse.so "$destino_lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$destino_lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$destino_lib/"
    
    # Si es tu pulseaudio.tzst de assets, inyectamos tus 53 módulos elásticos reales
    if [ "$archivo" == "pulseaudio.tzst" ]; then
      echo "  -> Rellenando subdirectorio de módulos elásticos..."
      mkdir -p "$tmp_dir/usr/lib/pulseaudio/modules"
      mkdir -p "$tmp_dir/modules"
      cp -a "$JNILIBS_DIR"/*.so "$tmp_dir/usr/lib/pulseaudio/modules/" 2>/dev/null || true
      cp -a "$JNILIBS_DIR"/*.so "$tmp_dir/modules/" 2>/dev/null || true
      
      # Quitar binarios core duplicados de la carpeta modules
      rm -f "$tmp_dir/modules/libpulse"* "$tmp_dir/usr/lib/pulseaudio/modules/libpulse"* || true
    fi

    # 3. RECONSTRUIR EL REDIRECCIONAMIENTO DIRECTO DE ALSA
    mkdir -p "$tmp_dir/etc"
    cat << 'EOF' > "$tmp_dir/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
ctl.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
EOF

    mkdir -p "$tmp_dir/etc/pulse"
    cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF
  fi

  # ============================================================================
  # 4. ENLACE FORZADO EN REGISTRO USER.REG PARA PROTON WINE
  # ============================================================================
  if [ -f "$tmp_dir/user.reg" ]; then
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
  fi

  # 5. Volver a cerrar el asset en máxima compresión ZSTD preservando symlinks
  echo "  -> Recomprimiendo asset purgado..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ESCANEO TOTAL: Forzamos la limpieza en tus contenedores y en tu pulseaudio.tzst
parchear_un_asset "container_pattern_common.tzst"
parchear_un_asset "proton-9.0-arm64ec_container_pattern.tzst"
parchear_un_asset "pulseaudio.tzst"

# Escanear cualquier otro archivo suelto de RootFS (como imagefs.tzst) que baje Gradle
for f in "$ASSETS_DIR"/*.tzst; do
  if [[ "$f" != *"container_pattern"* && "$f" != *"pulseaudio"* ]]; then
    parchear_un_asset "$(basename "$f")"
  fi
done

echo "=== ¡Defensa de PulseAudio 17.0 completada al 100%! ==="
