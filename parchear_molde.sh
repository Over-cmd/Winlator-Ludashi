#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$PWD"
ASSETS_DIR="$BASE_DIR/app/src/main/assets"

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

  # INYECCIÓN POR PROTOCOLO TCP (Bypass definitivo para solucionar Selected driver: None)
  # Forzamos a Wine a conectarse mediante un puerto de red local loopback (127.0.0.1)
  # saltándose por completo las librerías .so conflictivas de la RootFS.
  echo "  -> Configurando redirección TCP en el registro user.reg..."
  
  if [ -f "$tmp_dir/user.reg" ]; then
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="pulse,alsa"

[Software\\Wine\\PulseAudio]
"Server"="tcp:127.0.0.1:4713"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
    echo "  -> ¡Registro user.reg parcheado con éxito por TCP!"
  fi

  # Volver a cerrar el molde preservando la estructura física exacta
  echo "  -> Recomprimiendo $archivo_molde sin alterar enlaces..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo_molde"

  # Limpieza de temporales del runner
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR PARCHEO MASIVO EN AMBOS MOLDES DE TU REPOSITORIO
parchear_un_molde "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst"

echo "=== ¡Inyección de red TCP completada con éxito absoluto! ==="
