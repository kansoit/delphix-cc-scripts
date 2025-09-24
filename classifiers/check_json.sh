#!/bin/bash
# validar_json.sh
# Script para verificar si los archivos JSON de un directorio están bien formados

# Recorremos todos los archivos .json en el directorio actual
for f in *.json; do
  # Verificamos que exista al menos un archivo que coincida
  [ -e "$f" ] || { echo "No se encontraron archivos .json en este directorio"; exit 1; }

  # Validamos con jq
  if jq empty "$f" >/dev/null 2>&1; then
    echo "OK: $f"
  else
    echo "ERROR: $f"
  fi
done
