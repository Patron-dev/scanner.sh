#!/bin/bash

VERDE='\033[1;32m'
ROJO='\033[1;31m'
AMARILLO='\033[1;33m'
CIAN='\033[1;36m'
RESET='\033[0m'

clear
echo -e "${CIAN}═══════════════════════════════════════════════════${RESET}"
echo -e "${CIAN}        HOST & SSL SCANNER — INSTALADOR${RESET}"
echo -e "${CIAN}═══════════════════════════════════════════════════${RESET}"
echo ""

if command -v pkg &>/dev/null; then
    echo -e "${AMARILLO}📱 Detectado: Termux${RESET}"
    UPDATE_CMD="pkg update && pkg upgrade -y"
    INSTALL_CMD="pkg install -y bash coreutils curl openssl grep sed gawk findutils nano git"
elif command -v apt &>/dev/null; then
    echo -e "${AMARILLO}🖥️ Detectado: Debian / Ubuntu / VPS${RESET}"
    UPDATE_CMD="apt update && apt full-upgrade -y"
    INSTALL_CMD="apt install -y bash coreutils curl openssl grep sed gawk findutils nano git"
else
    echo -e "${ROJO}❌ Sistema no soportado automáticamente${RESET}"
    exit 1
fi

echo -e "${AMARILLO}🔄 Actualizando sistema...${RESET}"
eval "$UPDATE_CMD"

echo -e "${CIAN}📦 Instalando dependencias (SIN Whois)...${RESET}"
eval "$INSTALL_CMD"

echo -e "${CIAN}✅ Verificando que scanner.sh exista...${RESET}"
if [ ! -f "scanner.sh" ]; then
    echo -e "${ROJO}❌ scanner.sh NO encontrado!${RESET}"
    exit 1
fi

echo -e "${CIAN}🔍 Revisando sintaxis del script...${RESET}"
if bash -n scanner.sh; then
    echo -e "${VERDE}✅ Sintaxis OK${RESET}"
else
    echo -e "${ROJO}❌ Errores de sintaxis en scanner.sh${RESET}"
    exit 1
fi

chmod +x scanner.sh
chmod +x install.sh

echo -e "${VERDE}🎉 INSTALACIÓN COMPLETADA!${RESET}"
echo -e "${CIAN}👉 Ejecuta: ./scanner.sh${RESET}"
echo ""
read -p "Presiona ENTER para salir..."
