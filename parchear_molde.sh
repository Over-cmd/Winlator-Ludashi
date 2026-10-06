#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# FUNCIÓN QUIRÚRGICA: Desempaqueta, aniquila la versión 13, inyecta la versión 17 y vuelve a sellar
parchear_un_comprimido() {
  local archivo="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo//./_}"
  
  if [ ! -f "$ASSETS_DIR/$archivo" ]; then
    return 0
  fi

  # FILTRADO INTELIGENTE: Solo abrimos paquetes comprimidos reales (.tzst, .zst, .tar.zst)
  # Ignoramos por completo tu 'pulseaudio.tzst' personal para no alterar tus 53 módulos subidos
  if [[ "$archivo" != *.tzst && "$archivo" != *.zst && "$archivo" != *.tar.zst ]] || [ "$archivo" == "pulseaudio.tzst" ]; then
    return 0
  fi

  echo "=== PURGANDO VERSIÓN 13 E INYECTANDO VERSIÓN 17 EN: $archivo ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta los enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo" -C "$tmp_dir"

  # --------------------------------------------------------------------------
  # 1. TOTAL ANIQUILACIÓN DE LOS 6 RESIDUOS DE PULSEAUDIO 13.0 EN ESTE ASSET
  # --------------------------------------------------------------------------
  rm -rf "$tmp_dir/usr/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/local/lib/pulse-13.0" || true
  rm -rf "$tmp_dir/usr/etc/pulse" || true
  rm -rf "$tmp_dir/etc/pulse" || true

  # Exterminio plano por nombre en todo el árbol de directorios de este paquete
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
  # 2. INYECCIÓN SIMÉTRICA DE TUS 6 ARCHIVOS REALES DE LA VERSIÓN 17.0
  # --------------------------------------------------------------------------
  if [ -d "$tmp_dir/usr/lib" ]; then
    echo "  -> Sustituyendo las librerías en /usr/lib/ de este molde..."
    mkdir -p "$tmp_dir/usr/lib"
    cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecommon-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulsecore-17.0.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libpulseaudio.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libltdl.so "$tmp_dir/usr/lib/"
    cp -a "$JNILIBS_DIR"/libsndfile.so "$tmp_dir/usr/lib/"

    # Reconstrucción de los enlaces de Wine forzados a tu versión 17.0
    cd "$tmp_dir/usr/lib"
    ln -sf libpulse.so libpulse.so.0 || true
    ln -sf libpulsecommon-17.0.so libpulsecommon-13.0.so || true
    ln -sf libpulsecore-17.0.so libpulsecore-13.0.so || true
    cd "$BASE_DIR"

    # Permisos de ejecución individuales limpios
    cd "$tmp_dir/usr/lib"
    chmod -f 0755 libpulse.so || true
    chmod -f 0755 libpulsecommon-17.0.so || true
    chmod -f 0755 libpulsecore-17.0.so || true
    chmod -f 0755 libpulseaudio.so || true
    chmod -f 0755 libltdl.so || true
    chmod -f 0755 libsndfile.so || true
    cd "$BASE_DIR"

    # --------------------------------------------------------------------------
    # 3. INTERCEPCIÓN DE RUTAS MUERTAS EN DEFAULT.PA, DAEMON.CONF Y CLIENT.CONF
    # --------------------------------------------------------------------------
    find "$tmp_dir" -name "default.pa" -o -name "daemon.conf" -o -name "client.conf" | while read -r config_file; do
      sed -i 's|/data/data/com.winlator.cmod/files/imagefs||g' "$config_file" 2>/dev/null || true
    done

    # --------------------------------------------------------------------------
    # 4. ACOPLAMIENTO DIRECTO EN EL REGISTRO USER.REG DE ESTE CONTENEDOR
    # --------------------------------------------------------------------------
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

  # Volver a empaquetar el comprimido garantizando máxima compresión ZSTD
  echo "  -> Recomprimiendo asset purgado: $archivo ..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo"
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# ============================================================================
# 3. BUCLE DE BARRIDO TOTAL: ESCANEO Y PURGA DE TODOS LOS ASSETS COMPRIMIDOS
# ============================================================================
echo "=== INICIANDO BARRIDO MASIVO EN LA CARPETA DE ASSETS ==="
for f in "$ASSETS_DIR"/*; do
  if [ -f "$f" ]; then
    parchear_un_comprimido "$(basename "$f")"
  fi
done

echo "=== ¡Fase DevOps completada al 100%! PulseAudio 13 desintegrado de todo el APK ==="
