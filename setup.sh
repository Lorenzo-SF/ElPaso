#!/bin/bash

# Script de configuración para el proyecto ElPaso
# Este script configura el entorno de desarrollo según las consideraciones del documento v0.md

echo "Configurando entorno de desarrollo para ElPaso..."

# Verificar que se encuentra en el directorio correcto
if [ ! -d "elpaso" ]; then
    echo "Error: No se encuentra el directorio 'elpaso'. Asegúrate de estar en la raíz del proyecto."
    exit 1
fi

echo "Directorio de trabajo: $(pwd)"

# Crear directorios necesarios
mkdir -p logs
mkdir -p data
mkdir -p config

# Configurar variables de entorno (opcional)
echo "export EL_PASO_CONFIG_DIR=$(pwd)/config" > .env

echo "Configuración inicial completada."
echo "Directorio de trabajo: $(pwd)"