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
  echo "  -> Desempaquetando en caliente para inspección profunda..."
  mkdir -p "$tmp_dir"
  
  # Detectar el algoritmo de compresión real del asset para abrirlo sin corrupciones
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

  # ============================================================================
  # 1. PURGA ABSOLUTA RADICAL (El fin de la versión 13.0)
  # Busca y destruye de forma física cualquier binario viejo en todas las subcarpetas
  # ============================================================================
  echo "  -> Ejecutando purga destructiva de PulseAudio 13.0..."
  find "$tmp_dir" -name "*13.0.so" -delete || true
  rm -f "$tmp_dir/usr/lib/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/libpulsecore-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true
  rm -f "$tmp_dir/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/libpulsecore-13.0.so" || true

  # ============================================================================
  # 2. INYECTAR TU VERSIÓN ELÁSTICA MODERNA DE PULSEAUDIO 17.0
  # Si el asset tiene carpetas de sistema operativo (usr/lib), inyecta tus parches reales
  # ============================================================================
  if [ -d "$tmp_dir/usr/lib" ] || [ "$archivo" == "pulseaudio.tzst" ]; then
    echo "  -> Inyectando tus componentes de PulseAudio 17.0 del repositorio..."
    local ruta_destino="$tmp_dir/usr/lib"
    [ "$archivo" == "pulseaudio.tzst" ] && ruta_destino="$tmp_dir"
    
    mkdir -p "$ruta_destino"
    cp -a "$JNILIBS_DIR"/libpulsecommon.so "$ruta_destino/"
    cp -a "$JNILIBS_DIR"/libpulsecore.so "$ruta_destino/"
    cp -a "$JNILIBS_DIR"/libpulse.so "$ruta_destino/"
    
    # 3. RECONSTRUIR EL CABLE MAESTRO DE REDIRECCIÓN DE ALSA
    echo "  -> Configurando archivo maestro maestro de sistema /etc/asound.conf..."
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

    echo "  -> Configurando directivas del cliente de audio para PA 17.0..."
    mkdir -p "$tmp_dir/etc/pulse"
    cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF
  fi

  # ============================================================================
  # 4. PARCHE DE REGISTRO DIRECTO PARA ENTORNO WINE
  # ============================================================================
  if [ -f "$tmp_dir/user.reg" ]; then
    echo "  -> Forzando la inyección de llaves de sonido en el registro local..."
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
  fi

  # ============================================================================
  # 5. VOLVER A SELLAR EL ASSET PRESERVANDO PERMISOS Y ENLACES SIMBÓLICOS NATIVOS
  # ============================================================================
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
  echo "=== ¡Asset $archivo purgado y actualizado con éxito! ==="
}

# ESCANEO COMPLETO MASIVO DE LA CARPETA DE ASSETS
echo "=== INICIANDO BARRIDO GLOBAL MULTI-FORMATO EN ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_asset "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps completada al 100%! Todo rastro de la versión 13.0 ha sido eliminado ==="
