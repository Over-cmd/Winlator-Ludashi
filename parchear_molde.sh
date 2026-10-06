#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# 1. FUNCIÓN INTERNA DE PURGA ULTRA-DESTRUCTIVA DE LA VERSIÓN 13.0
parchear_un_asset() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  # VALIDACIÓN MAESTRA: Solo procesamos si es un archivo comprimido real (.tzst, .zst, .tar.zst)
  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]]; then
    return 0
  fi

  echo "=== ANIQUILANDO PULSEAUDIO 13 e INYECTANDO VERSIÓN 17 EN: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # --------------------------------------------------------------------------
  # ACCIÓN 1: TRITURACIÓN DE LOS 6 RESIDUOS DE LA VERSIÓN 13.0
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
  # ACCIÓN 2: SE EMBUTE TU VERSIÓN 17.0 SI EL ASSET CONTIENE CARPETAS DE SISTEMA
  # --------------------------------------------------------------------------
  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Sembrando tus 6 librerías limpias 17.0 en la ruta global de este molde..."
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"

    # Enlaces simbólicos requeridos para forzar a Wine a morder la versión 17.0
    cd "$tmp_dir/usr/lib"
    ln -sf libpulse.so libpulse.so.0 || true
    ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
    ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
    cd "$BASE_DIR"

    chmod -f 0755 "$tmp_dir/usr/lib"/libpulse*.so || true
    chmod -f 0755 "$tmp_dir/usr/lib"/libltdl*.so || true
    chmod -f 0755 "$tmp_dir/usr/lib"/libsndfile*.so || true

    # Cablear la infraestructura de ALSA nativa para tu tablet con Android 11
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

    # Romper el candado de rutas muertas en daemon.conf si existiera en este molde
    daemon_conf_path=$(find "$tmp_dir" -name "daemon.conf" -print -quit)
    if [ -n "$daemon_conf_path" ]; then
      sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
    fi

    # Registrar el puente multimedia directo en el user.reg local del molde
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

  # Volver a sellar el molde actual garantizando máxima compresión sin romper symlinks
  echo "  -> Recomprimiendo asset: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 2. FASE MAESTRA DE TRASVASE DE TUS MÓDULOS REALES DESDE TU PULSEAUDIO.TZST
# ============================================================================
TMP_PULSE="$BASE_DIR/tmp_pulseaudio_mod"
TMP_IMAGEFS="$BASE_DIR/tmp_imagefs_mod"

if [ -f "$ASSETS_DIR/pulseaudio.tzst" ] && [ -f "$ASSETS_DIR/imagefs.tar.zst" ]; then
  echo "=== PROCESANDO EXTRACCIÓN MAESTRA DE MÓDULOS DE TU PULSEAUDIO.TZST ==="
  mkdir -p "$TMP_PULSE"
  mkdir -p "$TMP_IMAGEFS"

  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/imagefs.tar.zst" -C "$TMP_IMAGEFS"
  tar -I 'zstd -d' -xf "$ASSETS_DIR/pulseaudio.tzst" -C "$TMP_PULSE"

  echo "  -> Sediando tus 53 módulos extraídos en la carpeta /usr/lib/pulseaudio/modules/ de la RootFS..."
  mkdir -p "$TMP_IMAGEFS/usr/lib/pulseaudio/modules"
  
  # Buscar la subcarpeta interna real de tus módulos dentro de tu pulseaudio.tzst
  RUTA_M_ORIGEN=$(find "$TMP_PULSE" -name "module-*.so" -print -quit)
  if [ -n "$RUTA_M_ORIGEN" ]; then
    DIR_M_ORIGEN=$(dirname "$RUTA_M_ORIGEN")
    cp -a "$DIR_M_ORIGEN"/*.so "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/" 2>/dev/null || true
  else
    cp -a "$TMP_PULSE"/*.so "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/" 2>/dev/null || true
  fi

  # Purgar binarios core de la subcarpeta de módulos para evitar bucles recursivos
  rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libpulse"* || true
  rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libltdl.so" || true
  rm -f "$TMP_IMAGEFS/usr/lib/pulseaudio/modules/libsndfile.so" || true

  echo "  -> Pasando patchelf directo a tus módulos en la RootFS..."
  find "$TMP_IMAGEFS/usr/lib/pulseaudio/modules" -name "*.so" | while read -r mod_file; do
    patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon-17.0.so "$mod_file" 2>/dev/null || true
    patchelf --replace-needed libpulsecore-17.0.so libpulsecore-17.0.so "$mod_file" 2>/dev/null || true
    patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
  done
  chmod -f 0755 "$TMP_IMAGEFS/usr/lib/pulseaudio/modules"/*.so || true

  # Volver a empaquetar la RootFS maestra con tus 53 módulos reales acoplados en su núcleo
  cd "$TMP_IMAGEFS"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/imagefs.tar.zst"
  cd "$BASE_DIR"
  rm -rf "$TMP_IMAGEFS" "$TMP_PULSE"
fi

# ============================================================================
# 3. ESCANEO GLOBAL ABSOLUTO EN BUCLE EN LA CARPETA DE ASSETS (CON FILTRADO)
# ============================================================================
echo "=== INICIANDO BARRIDO GENERAL EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_asset "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps destructiva completada! Todo rastro de la versión 13.0 ha dejado de existir ==="
