#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"
JNILIBS_DIR="$BASE_DIR/app/src/main/jniLibs/arm64-v8a"

# Forzar la eliminación física en caliente en la carpeta de compilación nativa por si Gradle los retiene
echo "-> Purgando residuos históricos de la carpeta jniLibs antes de empaquetar..."
rm -f "$JNILIBS_DIR"/libpulsecommon-13.0.so || true
rm -f "$JNILIBS_DIR"/libpulsecore-13.0.so || true

parchear_un_molde() {
  local archivo_molde="$1"
  local tmp_dir="$BASE_DIR/tmp_${archivo_molde%.*}"
  
  if [ ! -f "$ASSETS_DIR/$archivo_molde" ]; then
    echo "Aviso: El archivo $archivo_molde no existe en assets, saltando..."
    return 0
  fi

  echo "=== Parcheando de forma quirúrgica el molde: $archivo_molde ==="
  mkdir -p "$tmp_dir"
  
  # Desempaquetar preservando enlaces simbólicos nativos intactos
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo_molde" -C "$tmp_dir"

  # 1. PURGA RECURSIVA: Forzar el borrado de cualquier rastro en las subcarpetas del molde
  echo "  -> Purgando residuos antiguos 13.0 de la RootFS del molde..."
  find "$tmp_dir" -name "*13.0.so" -delete || true
  rm -f "$tmp_dir/usr/lib/libpulsecommon-13.0.so" || true
  rm -f "$tmp_dir/usr/lib/libpulsecore-13.0.so" || true

  # 2. RECONSTRUIR EL ARCHIVO ASOUND.CONF DE ALSA (El cable maestro para conectar con Wine)
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

  # 3. CONFIGURAR CLIENT.CONF DE PULSEAUDIO GLOBAL
  echo "  -> Configurando directivas del cliente de audio para PA 17.0..."
  mkdir -p "$tmp_dir/etc/pulse"
  cat << 'EOF' > "$tmp_dir/etc/pulse/client.conf"
default-server = unix:/tmp/pulse-socket
enable-shm = no
EOF

  # 4. PARCHE DE REGISTRO DIRECTO PARA ENTORNO WINE
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

  # 5. Volver a cerrar el asset PRESERVANDO ENLACES SIMBÓLICOS NATIVOS DE PROTON
  echo "  -> Recomprimiendo $archivo_molde sin alterar symlinks..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo_molde"

  # Limpieza de temporales del runner
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR PARCHEO EXCLUSIVO EN LOS MOLDES DE LOS CONTENEDORES
parchear_un_molde "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst"

echo "=== ¡Moldes purgados y sincronizados con éxito! ==="
