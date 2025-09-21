#!/usr/bin/bash

set -euo pipefail

# Solicitar el nombre de usuario
read -p "Introduce el nombre de usuario: " USERNAME

# Solicitar la contraseña de forma segura (sin que se muestre en pantalla)
read -s -p "Introduce la contraseña: " PASSWORD
echo # Para añadir un salto de línea después de la entrada de la contraseña

# Solicitar la dirección IP del Masking Engine
read -p "Introduce la dirección IP del Masking Engine: " MASKING_ENGINE

# Codificar el nombre de usuario y la contraseña en base64
ENCODED_USERNAME=$(echo -n "$USERNAME" | base64)
ENCODED_PASSWORD=$(echo -n "$PASSWORD" | base64)

# Guardar las credenciales y la IP en el archivo CONFIG
# Se sobrescribirá el archivo si ya existe
echo "$ENCODED_USERNAME" > CONFIG
echo "$ENCODED_PASSWORD" >> CONFIG
echo "$MASKING_ENGINE" >> CONFIG

echo "Configuración guardada en el archivo CONFIG correctamente."
