#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# 1. FUNCIÓN INTERNA DE PURGA SUSTITUTIVA DE LIBRERÍAS
parchear_un_asset() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  # VALIDACIÓN DE FORMATO: Solo procesamos si es un archivo comprimido real (.tzst, .zst, .tar.zst)
  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]]; then
    return 0
  fi

  # EVITAR COMPFLICTOS: Tu pulseaudio.tzst ya está perfecto en tu repositorio, no lo tocamos
  if [ "$archivo" == "pulseaudio.tzst" ]; then
    return 0
  fi

  echo "=== PURGANDO VERSIÓN 13 E INYECTANDO TUS 6 LIBRERÍAS 17 EN: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # --------------------------------------------------------------------------
  # ACCIÓN 1: TRITURACIÓN DE LOS 6 RESIDUOS DE LA VERSIÓN 13.0 PARA QUE NO APAREZCAN NUNCA MÁS
  # --------------------------------------------------------------------------
  rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/etc/pulse" || true

  find "$tmp_dir" -name "libpulsecommon-13.0.so" -delete || true
  find "$tmp_dir" -name "libpulsecore-13.0.so" -delete || true
  find "$tmp_dir" -name "libpulse.so" -delete || true
  find "$tmp_dir" -name "libpulse.so.0" -delete || true
  find "$tmp_dir" -name "libpulseaudio.so" -delete || true
  find "$tmp_dir" -name "libltdl.so" -delete || true
  find "$tmp_dir" -name "libltdl.so.7" -delete || true
  find "$tmp_dir" -name "libsndfile.so" -delete || true
  find "$tmp_dir" -name "libsndfile.so.1" -delete || true

  # --------------------------------------------------------------------------
  # ACCIÓN 2: SUSTITUCIÓN DE TUS 6 ARCHIVOS NUEVOS 17.0 EN /usr/lib/ (arm64-v8a)
  # --------------------------------------------------------------------------
  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Sembrando tus 6 librerías limpias de la versión 17.0..."
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"

    # Enlaces simbólicos requeridos para que Wine muerda la versión 17.0 directamente
    cd "$tmp_dir/usr/lib"
    ln -sf libpulse.so libpulse.so.0 || true
    ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
    ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
    cd "$BASE_DIR"

    # Permisos individuales para evitar colisiones con enlaces rotos de gráficos
    cd "$tmp_dir/usr/lib"
    chmod -f 0755 libpulse.so || true
    chmod -f 0755 libpulsecommon-17.0.so || true
    chmod -f 0755 libpulsecore-17.0.so || true
    chmod -f 0755 libpulseaudio.so || true
    chmod -f 0755 libltdl.so || true
    chmod -f 0755 libsndfile.so || true
    cd "$BASE_DIR"

    # Cablear la infraestructura de ALSA nativa para el chroot
    mkdir -p "$tmp_dir/usr/etc/pulse"
    cat << 'EOF' > "$tmp_dir/usr/etc/asound.conf"
pcm.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
ctl.!default {
    type android_aserver
    socket "/tmp/pulse-socket"
}
EOF
    cat << 'EOF' > "$tmp_dir/usr/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

    # Romper el candado de rutas muertas heredadas en daemon.conf si existiera
    daemon_conf_path=$(find "$tmp_dir" -name "daemon.conf" -print -quit)
    if [ -n "$daemon_conf_path" ]; then
      sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
    fi

    # Registrar el puente multimedia en el user.reg local del contenedor
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

  # Volver a sellar el asset garantizando máxima compresión sin romper symlinks
  echo "  -> Recomprimiendo asset: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 3. ESCANEO GLOBAL EN BUCLE SOBRE LOS COMPRIMIDOS DE LA CARPETA DE ASSETS
# ============================================================================
echo "=== INICIANDO BARRIDO GENERAL EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_asset "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps completada! 6 quitadas, 6 puestas y 13 eliminada para siempre ==="
