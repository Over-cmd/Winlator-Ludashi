#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

parchear_un_molde() {
  local archivo_molde="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo_molde%.*}"
  
  if [ ! -f "$ASSETS_DIR/$archivo_molde" ]; then
    echo "Aviso: El archivo $archivo_molde no existe en assets, saltando..."
    return 0
  fi

  echo "=== Parcheando el molde: $archivo_molde ==="
  mkdir -p "$tmp_dir"
  tar -I 'zstd -d' -xf "$ASSETS_DIR/$archivo_molde" -C "$tmp_dir"

  # 1. Purgar físicamente las librerías muertas de la versión 13.0
  echo "  -> Eliminando residuos antiguos 13.0..."
  rm -f "$tmp_dir/usr/lib/libpulsecommon-13.0.so"
  rm -f "$tmp_dir/usr/lib/libpulsecore-13.0.so"
  rm -f "$tmp_dir/home/xuser/libpulse"* || true

  # 2. Inyectar las 3 librerías compartidas de PulseAudio 17.0 (Limpias de patchelf)
  echo "  -> Inyectando componentes de PulseAudio 17.0 a /usr/lib/ ..."
  mkdir -p "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulsecommon.so "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulsecore.so "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"

  # 3. RECONSTRUIR EL ARCHIVO ASOUND.CONF DE ALSA (Para forzar Driver: alsa)
  echo "  -> Creando archivo maestro /etc/asound.conf..."
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

# 4. CONFIGURAR CLIENT.CONF DE PULSEAUDIO
  echo "  -> Configurando directivas en /etc/pulse/client.conf..."
  mkdir -p "$tmp_dir/etc/pulse"
  cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

  # 5. Volver a cerrar el molde con máxima compresión ZSTD usando todos los hilos
  echo "  -> Recomprimiendo $archivo_molde..."
  cd "$tmp_dir"
  tar -cvf - * | zstd -19 -T0 > "$ASSETS_DIR/$archivo_molde"

  # Limpieza
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR PARCHEO MASIVO EN AMBOS MOLDES (x86_64 y ARM64EC)
parchear_un_molde "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst"

echo "=== ¡Todos los moldes de assets actualizados con éxito con PulseAudio 17.0! ==="
