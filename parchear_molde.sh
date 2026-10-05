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

  echo "=== DETECTADO ASSET CRÍTICO: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando enlaces simbólicos y permisos nativos de Linux
  if [[ "$archivo" == *.tzst || "$archivo" == *.zst ]]; then
    tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"
  elif [[ "$archivo" == *.tar.xz || "$archivo" == *.txz ]]; then
    tar -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"
  elif [[ "$archivo" == *.tar.gz || "$archivo" == *.tgz ]]; then
    tar -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"
  else
    rm -rf "$tmp_dir"
    return 0
  fi

  # 1. PURGA ABSOLUTA DE RESIDUOS DE LA VERSIÓN 13.0
  find "$tmp_dir" -name "*13.0.so" -delete || true
  rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true

  # ============================================================================
  # 2. INYECTAR LIBRERÍAS Y MÓDULOS DE LA VERSIÓN 17.0
  # ============================================================================
  if [ -d "$tmp_dir/usr/lib" ] || [ "$archivo" == "pulseaudio.tzst" ]; then
    echo "  -> Inyectando componentes cliente de PulseAudio 17.0..."
    local ruta_lib="$tmp_dir/usr/lib"
    [ "$archivo" == "pulseaudio.tzst" ] && ruta_lib="$tmp_dir"
    
    mkdir -p "$ruta_lib"
    cp -a "$JNILIBS_DIR"/libpulsecommon.so "$ruta_lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore.so "$ruta_lib/"
    cp -a "$JNILIBS_DIR"/libpulse.so "$ruta_lib/"

    # CORRECCIÓN DE MÓDULOS: Creamos las dos rutas del sistema donde Wine y el demonio
    # buscarán de forma nativa los 53 módulos elásticos compilados de la versión 17.0
    echo "  -> Estructurando carpetas e inyectando los módulos elásticos modernos..."
    mkdir -p "$tmp_dir/usr/local/lib/pulseaudio/modules"
    mkdir -p "$tmp_dir/usr/lib/pulseaudio/modules"
    
    # Si tienes los módulos .so de la versión 17 compilados en alguna carpeta de origen,
    # el comando cp se encargará de rellenar los directorios automáticamente:
    if [ -d "audio_plugin/modules" ]; then
      cp -a audio_plugin/modules/*.so "$tmp_dir/usr/local/lib/pulseaudio/modules/" 2>/dev/null || true
      cp -a audio_plugin/modules/*.so "$tmp_dir/usr/lib/pulseaudio/modules/" 2>/dev/null || true
    fi
    
    # 3. RECONSTRUIR EL CABLE DE REDIRECCIÓN DE ALSA (Para forzar Driver: alsa)
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

  # 4. PARCHE DE REGISTRO DIRECTO PARA ENTORNO WINE
  if [ -f "$tmp_dir/user.reg" ]; then
    echo "  -> Inyectando llaves de sonido nativas en user.reg..."
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
  fi

  # 5. VOLVER A SELLAR EL ASSET PRESERVANDO LOS PERMISOS NATIVOS
  echo "  -> Volviendo a empaquetar $archivo de forma limpia..."
  cd "$tmp_dir"
  if [[ "$archivo" == *.tzst || "$archivo" == *.zst ]]; then
    find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  elif [[ "$archivo" == *.tar.xz || "$archivo" == *.txz ]]; then
    find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | xz -9 -T0 > "$ASSETS_DIR/$archivo"
  elif [[ "$archivo" == *.tar.gz || "$archivo" == *.tgz ]]; then
    find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | gzip -9 > "$ASSETS_DIR/$archivo"
  fi

  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

echo "=== INICIANDO BARRIDO GLOBAL MULTI-FORMATO EN ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_asset "$(basename "$f")"
  fi
done
echo "=== ¡Fase DevOps completada al 100%! ==="
