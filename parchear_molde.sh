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

  echo "=== Parcheando de forma quirúrgica el asset: $archivo_molde ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando de forma estricta los enlaces simbólicos y permisos de Linux
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo_molde" -C "$tmp_dir"

  # 1. PURGA DEFINITIVA: Forzamos el borrado físico y recursivo de cualquier binario con sufijo -13.0.so
  echo "  -> Eliminando de forma recursiva los residuos de PulseAudio 13.0..."
  find "$tmp_dir" -name "*13.0.so" -delete || true
  rm -f "$tmp_dir/usr/lib/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/libpulsecore-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/aarch64-linux-gnu/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/aarch64-linux-gnu/libpulsecore-13.0.so" || true

  # 2. INYECTAR TUS LIBRERÍAS MAESTRAS DE LA VERSIÓN 17.0 CON NOMBRE LIMPIO
  echo "  -> Inyectando componentes de PulseAudio 17.0 a /usr/lib/ ..."
  mkdir -p "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulsecommon.so "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulsecore.so "$tmp_dir/usr/lib/"
  cp -a "$JNILIBS_DIR"/libpulse.so "$tmp_dir/usr/lib/"

  # 3. RECONSTRUIR EL ARCHIVO ASOUND.CONF DE ALSA (El cable maestro para quitar Driver: None)
  echo "  -> Creando archivo maestro de sistema /etc/asound.conf..."
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

  # 4. CONFIGURAR CLIENT.CONF DE PULSEAUDIO GLOBAL
  echo "  -> Configurando directivas del cliente de audio para PA 17.0..."
  mkdir -p "$tmp_dir/etc/pulse"
  cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

  # 5. PARCHE DE REGISTRO DIRECTO PARA ENTORNO WINE (user.reg)
  if [ -f "$tmp_dir/user.reg" ]; then
    echo "  -> Forzando la inyección de llaves de sonido en el registro..."
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
  fi

  # 6. Volver a cerrar el asset preservando la estructura física limpia de symlinks de Linux
  echo "  -> Recomprimiendo $archivo_molde sin alterar enlaces..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo_molde"

  # Limpieza de temporales del runner
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR PARCHEO MASIVO EN MOLDES Y BUSCAR EL ARCHIVO COMPRIMIDO DE LA IMAGEFS EN LOS ASSETS
parchear_un_molde "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst"

# Forzar el escaneo y purga en caliente sobre cualquier imagen de RootFS extraída en el directorio assets
for f in "$ASSETS_DIR"/*.tzst; do
  if [[ "$f" != *"container_pattern"* ]]; then
    parchear_un_molde "$(basename "$f")"
  fi
done

echo "=== ¡Purga de residuos históricos completada al 100% en toda la estructura nativa! ==="
