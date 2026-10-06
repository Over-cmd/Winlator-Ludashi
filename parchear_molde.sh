#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

parchear_un_asset() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    echo "Aviso: No se encontró el asset $archivo, saltando..."
    return 0
  fi

  echo "=== PROCESANDO ASSET CRÍTICO: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta los enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # ============================================================================
  # CASO 1: TU ARCHIVO DE AUDIO MAESTRO (PULSEAUDIO.TZST)
  # Aquí rellenamos de forma física la ruta privada que Java exige en el teléfono
  # ============================================================================
  if [ "$archivo" == "pulseaudio.tzst" ]; then
    echo "  -> Limpiando estructura vieja y corrupta de pulseaudio.tzst..."
    rm -rf "$tmp_dir/etc" "$tmp_dir/usr" "$tmp_dir/modules" || true
    rm -f "$tmp_dir"/*.so || true
    
    # CREAMOS LA RUTA EXACTA QUE BUSCA TU LÍNEA DE JAVA: modules/arm64
    echo "  -> Creando el directorio rígido de Java: modules/arm64 ..."
    mkdir -p "$tmp_dir/modules/arm64"

    # Copiamos tus 6 librerías clientes base a la raíz del asset
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/"

    # INYECCIÓN MASIVA DE MÓDULOS: Copiamos todos tus módulos .so de jniLibs dentro de modules/arm64
    echo "  -> Volcando tus 53 módulos reales de la versión 17.0 en la ruta de Java..."
    cp -a "$JNILIBS_DIR"/*.so "$tmp_dir/modules/arm64/" 2>/dev/null || true
    
    # Limpiamos los binarios core duplicados de la subcarpeta para dejar solo los módulos puros
    rm -f "$tmp_dir/modules/arm64/libpulse"* "$tmp_dir/modules/arm64/libltdl.so" "$tmp_dir/modules/arm64/libsndfile.so" || true

    # Pasamos patchelf masivo para corregir las firmas ELF internas de todos tus archivos inyectados
    echo "  -> Corrigiendo identidades dinámicas con patchelf..."
    find "$tmp_dir" -name "*.so" | while read -r mod_file; do
      patchelf --replace-needed libpulsecommon-17.0.so libpulsecommon-17.0.so "$mod_file" 2>/dev/null || true
      patchelf --replace-needed libpulsecore-17.0.so libpulsecore-17.0.so "$mod_file" 2>/dev/null || true
      patchelf --set-soname "$(basename "$mod_file")" "$mod_file" 2>/dev/null || true
    done

  # ============================================================================
  # CASO 2: LA ROOTFS COMPLETA DEL SISTEMA OPERATIVO (IMAGEFS.TAR.ZST)
  # ============================================================================
  elif [ "$archivo" == "imagefs.tar.zst" ]; then
    echo "  -> Triturando componentes viejos 13.0 de la RootFS base..."
    rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true
    rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
    find "$tmp_dir" -name "*13.0.so" -delete || true

    echo "  -> Sembrando tus 6 binarios reales 17.0 en la carpeta global /usr/lib/ ..."
    mkdir -p "$tmp_dir/usr/lib"
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"
    chmod -f 0755 "$tmp_dir/usr/lib"/lib*.so || true

    # Corregir el archivo daemon.conf en la ruta real que viste en ZArchiver
    local daemon_conf_path=$(find "$tmp_dir" -name "daemon.conf" -print -quit)
    if [ -n "$daemon_conf_path" ]; then
      sed -i 's/; default-script-file =/default-script-file =/g' "$daemon_conf_path"
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$daemon_conf_path"
    fi

    # Configurar de forma nativa el archivo maestro de ALSA al cable Unix de Android 11
    echo "  -> Conectando el cable maestro /usr/etc/asound.conf..."
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

    # Forzar las directivas en el registro de Windows del chroot
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

  # Volver a sellar el asset comprimido de forma segura manteniendo los enlaces simbólicos de Linux
  echo "  -> Recomprimiendo $archivo de forma limpia..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR EL PARCHEO MAESTRO SIMULTÁNEO EN AUDIO Y ROOTFS
parchear_un_asset "imagefs.tar.zst"
parchear_un_asset "pulseaudio.tzst"

echo "=== ¡Sincronización total completada con la carpeta modules/arm64 de Java! ==="
