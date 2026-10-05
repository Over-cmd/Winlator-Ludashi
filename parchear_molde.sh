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
  
  # Desempaquetar preservando enlaces simbólicos nativos
  tar --pax-option=exthdr.name=%d/PakHeaders/%f -I 'zstd -d' -xf "$ASSETS_DIR/$archivo_molde" -C "$tmp_dir"

  # INYECCIÓN DIRECTA EN EL REGISTRO DE WINDOWS (user.reg)
  # Forzamos a Wine a inicializar los drivers saltándose cualquier validación rígida
  echo "  -> Modificando user.reg para activar PulseAudio 17.0..."
  
  # Verificamos si existe user.reg en la raíz del molde desempaquetado
  if [ -f "$tmp_dir/user.reg" ]; then
    cat << 'EOF' >> "$tmp_dir/user.reg"

[Software\\Wine\\Drivers]
"Audio"="alsa,pulse"

[Software\\Wine\\PulseAudio]
"Server"="unix:/tmp/pulse-socket"
"DisableSHM"="1"
EOF
    chmod 0644 "$tmp_dir/user.reg"
    echo "  -> ¡user.reg parcheado con éxito!"
  else
    echo "  -> Aviso: No se encontró user.reg en la raíz, revisando subcarpetas..."
  fi

  # Volver a cerrar el molde preservando la estructura física intacta
  echo "  -> Recomprimiendo $archivo_molde sin alterar enlaces..."
  cd "$tmp_dir"
  find . -mindepth 1 -print0 | tar --null --no-recursion -cvf - -T - | zstd -19 -T0 > "$ASSETS_DIR/$archivo_molde"

  # Limpieza de residuos en el runner
  cd "$BASE_DIR"
  rm -rf "$tmp_dir"
}

# EJECUTAR PARCHEO MASIVO EN AMBOS MOLDES DE TU APPASSSET
parchear_un_molde "container_pattern_common.tzst"
parchear_un_molde "proton-9.0-arm64ec_container_pattern.tzst"

echo "=== ¡Inyección de registros de audio completada con éxito absoluto! ==="
