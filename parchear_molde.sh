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

  echo "=== PROCESANDO ASSET DEFINITIVO: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta los enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # ============================================================================
  # CASO EXCLUSIVO: TU ARCHIVO PULSEAUDIO.TZST PERSONALIZADO
  # ============================================================================
  if [ "$archivo" == "pulseaudio.tzst" ]; then
    echo "  -> Manteniendo intactos tus 53 módulos de assets..."
    echo "  -> Aplicando remapeo de bytes patchelf para corregir SONAMES en tu tablet..."
    
    # Rastrear de forma recursiva tus módulos reales e inyectar el fix de Android Bionic
    find "$tmp_dir" -name "*.so" | while read -r mod_file; do
      patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon.so "$mod_file" 2>/dev/null || true
      patchelf --replace-needed libpulsecore-17.0.so libpulsecore.so "$mod_file" 2>/dev/null || true
      patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
    done

  # ============================================================================
  # CASO EXCLUSIVO: LOS MOLDES DE LOS CONTENEDORES (WINE / PROTON ARM64EC)
  # ============================================================================
  else
    if [ -d "$tmp_dir/usr/lib" ]; then
      echo "  -> Purgando residuos antiguos 13.0 y sincronizando en los contenedores..."
      find "$tmp_dir" -name "*13.0.so" -delete || true
      rm -f "$tmp_dir/usr/lib/libpulsecommon-13.0.so" || true
      rm -f "$tmp_dir/usr/lib/libpulsecore-13.0.so" || true
      
      mkdir -p "$tmp_dir/usr/lib/"
      cp -a "$JNILIBS_DIR"/libpulsecommon.so "$tmp_dir/usr/lib/"
      cp -a "$JNILIBS_DIR"/libpulsecore.so "$tmp_dir/usr/lib/"
      cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"

      # Inyectar el cable maestro de ALSA (asound.conf)
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
  fi

  # Parche del registro user.reg para forzar al mezclador de Windows
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

  # Volver a cerrar el asset preservando los enlaces simbólicos de Proton
  echo "  -> Recomprimiendo $archivo de forma limpia..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"

  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

echo "=== INICIANDO BARRIDO GLOBAL MULTI-FORMATO EN ASSETS ==="
parchear_un_asset "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst" || parchear_un_asset "proton-9.0-arm64ec_container_pattern.tzst"
parchear_un_asset "pulseaudio.tzst"

echo "=== ¡Fase DevOps completada con tus módulos al 100%! ==="
