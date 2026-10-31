#!/bin/bash

# ==============================================================
#  VALIDADOR DE HOSTS & SEGURIDAD SSL — Versión Empresarial
#  Desarrollado por: FelixVpn 🇳🇮
#  © 2026 — Todos los derechos reservados
# ==============================================================

VERDE='\033[1;32m'
ROJO='\033[1;31m'
AMARILLO='\033[1;33m'
CIAN='\033[1;36m'
BLANCO='\033[1;37m'
GRIS='\033[0;37m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

REPORTE_DIR="./reportes"
mkdir -p "$REPORTE_DIR"

# ==============================================
validar_conexion() {
    local host="$1"
    respuesta=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" --connect-timeout 8 --max-time 12 --insecure \
        -L -X GET -H "Host: $host" -H "Connection: keep-alive" \
        -A "Mozilla/5.0 (compatible; HostValidator/1.0)" "https://$host" 2>/dev/null)
    
    codigo=$(echo "$respuesta" | awk '{print $1}')
    tiempo=$(echo "$respuesta" | awk '{print $2}')
    
    if [ -z "$codigo" ] || [ "$codigo" = "000" ]; then
        echo -e "${ROJO}├─── ❌ NO SIRVE${RESET}"
        echo -e "${ROJO}│    └── Sin respuesta — Tiempo de espera agotado${RESET}"
        echo "❌ NO SIRVE | $host | Sin respuesta" >> "$REPORTE_DIR/ultimo_reporte.txt"
        return 1
    fi
    
    case "$codigo" in
        200)
            echo -e "${VERDE}├─── ✅ SÍ SIRVE${RESET}"
            echo -e "${VERDE}│    ├── Código:   ${BLANCO}HTTP/1.1 $codigo OK${RESET}"
            echo -e "${VERDE}│    └── Tiempo:   ${BLANCO}${tiempo}s${RESET}"
            echo "✅ SÍ SIRVE | $host | HTTP $codigo OK" >> "$REPORTE_DIR/ultimo_reporte.txt"
            ;;
        301|302|304|307|308)
            echo -e "${AMARILLO}├─── ⚠️  REDIRECCIÓN${RESET}"
            echo -e "${AMARILLO}│    ├── Código:   ${BLANCO}HTTP/1.1 $codigo${RESET}"
            echo -e "${AMARILLO}│    └── Tiempo:   ${BLANCO}${tiempo}s${RESET}"
            echo "⚠️  REDIRECCIÓN | $host | HTTP $codigo" >> "$REPORTE_DIR/ultimo_reporte.txt"
            ;;
        400|401|403|404|405|408|429)
            echo -e "${ROJO}├─── ❌ ERROR DEL CLIENTE${RESET}"
            case "$codigo" in
                400) msg="Solicitud incorrecta" ;;
                401) msg="No autorizado" ;;
                403) msg="Acceso prohibido" ;;
                404) msg="No encontrado" ;;
                405) msg="Método no permitido" ;;
                408) msg="Solicitud agotada" ;;
                429) msg="Demasiadas solicitudes" ;;
            esac
            echo -e "${ROJO}│    ├── Código:   ${BLANCO}HTTP/1.1 $codigo — $msg${RESET}"
            echo -e "${ROJO}│    └── Tiempo:   ${BLANCO}${tiempo}s${RESET}"
            echo "❌ ERROR | $host | HTTP $codigo — $msg" >> "$REPORTE_DIR/ultimo_reporte.txt"
            ;;
        500|502|503|504)
            echo -e "${ROJO}├─── ❌ ERROR DEL SERVIDOR${RESET}"
            case "$codigo" in
                500) msg="Error interno del servidor" ;;
                502) msg="Puerta de enlace incorrecta" ;;
                503) msg="Servicio no disponible" ;;
                504) msg="Tiempo agotado — Puerta de enlace" ;;
            esac
            echo -e "${ROJO}│    ├── Código:   ${BLANCO}HTTP/1.1 $codigo — $msg${RESET}"
            echo -e "${ROJO}│    └── Tiempo:   ${BLANCO}${tiempo}s${RESET}"
            echo "❌ ERROR SERVIDOR | $host | HTTP $codigo — $msg" >> "$REPORTE_DIR/ultimo_reporte.txt"
            ;;
        *)
            echo -e "${AMARILLO}├─── ⚠️  RESPUESTA: ${BLANCO}HTTP $codigo${RESET}"
            echo "⚠️  DESCONOCIDO | $host | HTTP $codigo" >> "$REPORTE_DIR/ultimo_reporte.txt"
            ;;
    esac
    return 0
}

# ==============================================
validar_certificado() {
    local h="$1"
    salida=$(echo | timeout 12 openssl s_client -connect "$h:443" -servername "$h" 2>&1)
    
    if echo "$salida" | grep -q "CONNECTED"; then
        cn=$(echo "$salida" | grep -oE "s:CN=[^\n]+" | head -1 | sed 's/s:CN=//')
        issuer=$(echo "$salida" | grep -oE "i:CN=[^\n]+" | head -1 | sed 's/i:CN=//')
        fecha_fin=$(echo "$salida" | grep -oE "Not After[^\n]+" | sed 's/Not After : //')
        
        echo -e "${CIAN}├─── 🔒 CERTIFICADO SSL${RESET}"
        echo -e "${CIAN}│    ├── Dominio:   ${BLANCO}$cn${RESET}"
        echo -e "${CIAN}│    ├── Emisor:    ${BLANCO}$issuer${RESET}"
        echo -e "${CIAN}│    ├── Vence:     ${BLANCO}$fecha_fin${RESET}"
        
        if echo "$salida" | grep -q "verify return:1"; then
            echo -e "${VERDE}│    └── Estado:    ✅ VÁLIDO${RESET}"
            echo "🔒 CERTIFICADO VÁLIDO | $host | CN=$cn | Emisor=$issuer" >> "$REPORTE_DIR/ultimo_reporte.txt"
        else
            echo -e "${AMARILLO}│    └── Estado:    ⚠️  CON ADVERTENCIAS${RESET}"
            echo "🔒 CERTIFICADO ADVERTENCIA | $host | CN=$cn" >> "$REPORTE_DIR/ultimo_reporte.txt"
        fi
    else
        echo -e "${ROJO}├─── 🔒 CERTIFICADO SSL${RESET}"
        echo -e "${ROJO}│    └── ❌ No se pudo establecer conexión SSL${RESET}"
        echo "🔒 SIN CONEXIÓN SSL | $host" >> "$REPORTE_DIR/ultimo_reporte.txt"
    fi
}

# ==============================================
escanear_host() {
    local host="$1"
    echo -e ""
    echo -e "${VERDE}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${VERDE}║${RESET}  ${CIAN}▶ ESCANEANDO:${BLANCO} $host${RESET}"
    echo -e "${VERDE}╚══════════════════════════════════════════════════════════╝${RESET}"
    
    echo -e "${GRIS}  ── FASE 1: CONEXIÓN HTTP ────────────────────────────────${RESET}"
    validar_conexion "$host"
    sleep 0.5
    
    echo -e "${GRIS}  ── FASE 2: CERTIFICADO SSL ──────────────────────────────${RESET}"
    validar_certificado "$host"
    
    echo -e "${VERDE}╚══════════════════════════════════════════════════════════╝${RESET}"
    sleep 0.3
}

# ==============================================
guardar_reporte() {
    local nombre="$1"
    if [ -z "$nombre" ]; then
        nombre="reporte_$(date +%Y%m%d_%H%M%S)"
    fi
    cp "$REPORTE_DIR/ultimo_reporte.txt" "$REPORTE_DIR/${nombre}.txt"
    echo -e "${VERDE}✅ Reporte guardado como: ${BLANCO}reportes/${nombre}.txt${RESET}"
}

# ==============================================
listar_reportes() {
    clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░        📂 LISTA DE REPORTES GUARDADOS   ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
    
    if [ -z "$(ls -A "$REPORTE_DIR"/ 2>/dev/null)" ]; then
        echo -e "${AMARILLO}  ℹ️  No hay reportes guardados aún${RESET}"
    else
        ls -lh "$REPORTE_DIR"/ | grep ".txt$" | awk '{print NR". "$9" ("$5")"}'
    fi
    volver_menu
}

# ==============================================
eliminar_reporte() {
    clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░        🗑️  ELIMINAR REPORTE             ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
    
    echo -ne "${CIAN}  ► Nombre del archivo a eliminar (sin .txt): ${RESET}"
    read nombre
    ruta="$REPORTE_DIR/${nombre}.txt"
    
    if [ -f "$ruta" ]; then
        rm -f "$ruta"
        echo -e "${VERDE}✅ Archivo eliminado correctamente${RESET}"
    else
        echo -e "${ROJO}✖ Archivo no encontrado${RESET}"
    fi
    sleep 1
    volver_menu
}

# ==============================================
ver_creditos() {
    clear

echo -e "${MAGENTA}"
echo -e "          /\\_/\\  "
echo -e "         /    \\ "
echo -e "        /      \\"
echo -e "       /  **   \\"
echo -e "      /  ****   \\"
echo -e "     /  ******   \\"
echo -e "    /  ********   \\"
echo -e "   /  **********   \\"
echo -e "  /  ************   \\"
echo -e " /  **************   \\"
echo -e " \\_________________/"
echo -e "${RESET}"

echo -e "${AMARILLO}"
echo -e "        👤  DESARROLLADOR"
echo -e "${RESET}"

echo -e "${CIAN}"
echo -e " By  FelixVpn — Comprobador de respuestas 🐉"

echo -e "${RESET}"

echo -e "${AMARILLO}"
echo -e " 📬 CONTACTO DIRECTO"
echo -e "${RESET}"

echo -e "${VERDE}"
echo -e " ✈️  Telegram   "
echo -e " 🔗  t.me/null_ptr_404"
echo -e ""
echo -e " 💬 WhatsApp "
echo -e " 🔗  wa.me/50557151281"
echo -e "${RESET}"

echo -e "${AMARILLO}"
echo -e " 🚀 SERVICIOS"
echo -e "${RESET}"

echo -e "${CIAN}"
echo -e " • Validación y Monitoreo de Infraestructura"
echo -e " • Auditoria en Redes"
echo -e " • Desarrollo de Herramientas Personalizadas"
echo -e " • Consultoria"
echo -e "${RESET}"

echo -e "${AMARILLO}"
echo -e " © 2026 — Todos los derechos reservados"
echo -e "          Versión Empresarial — v5.0"
echo -e "${RESET}"

echo ""
read -p "Presione ENTER para regresar al menú principal..."
volver_menu
}

# ==============================================
volver_menu() {
    echo -e ""
    echo -e "${GRIS}└─── Presiona ${BLANCO}ENTER${GRIS} para regresar al menú principal...${RESET}"
    read
    clear
}

# ==============================================
while true; do
    clear
    
echo -e "${VERDE}"
echo -e "   ██╗   ██╗██████╗ ██╗     ██╗ ██████╗ ███████╗"
echo -e "   ██║   ██║██╔══██╗██║     ██║██╔════╝ ██╔════╝"
echo -e "   ██║   ██║██████╔╝██║     ██║██║  ███╗█████╗  "
echo -e "   ██║   ██║██╔══██╗██║     ██║██║   ██║██╔══╝  "
echo -e "   ╚██████╔╝██║  ██║███████╗██║╚██████╔╝███████╗"
echo -e "    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚══════╝"
echo -e "${CIAN}"
echo -e "      ════════════════════════════════════════════"
echo -e "           VALIDADOR DE HOSTS & SEGURIDAD SSL"
echo -e "                  Versión Empresarial 5.0"
echo -e "      ════════════════════════════════════════════"
echo -e "${RESET}"

    echo -e "${BLANCO}  MENÚ PRINCIPAL${RESET}"
    echo -e "${GRIS}──────────────────────────────────────────────────${RESET}"
    echo -e "${VERDE}  [ 1 ]${RESET}  🛜  Validar Un Solo Host"
    echo -e "${VERDE}  [ 2 ]${RESET}  🔒  Verificar Certificado SSL"
    echo -e "${VERDE}  [ 3 ]${RESET}  🔍  Escanear Múltiples Hosts (Lote)"
    echo -e "${MAGENTA}  [ 4 ]${RESET}  📄  Ver Reporte Último Escaneo"
    echo -e "${MAGENTA}  [ 5 ]${RESET}  💾  Guardar Reporte con nombre"
    echo -e "${MAGENTA}  [ 6 ]${RESET}  📂  Listar Todos los Reportes"
    echo -e "${MAGENTA}  [ 7 ]${RESET}  🗑️  Eliminar Reporte Guardado"
    echo -e "${MAGENTA}  [ 8 ]${RESET}  👤  Créditos y Contacto"
    echo -e "${ROJO}  [ 0 ]${RESET}  🚪  Salir del Sistema"
    echo -e "${GRIS}──────────────────────────────────────────────────${RESET}"
    echo -ne "${CIAN}  ► Selecciona una opción: ${RESET}"
    read opcion
    
    case "$opcion" in
        1)
            clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░        🛜 VALIDACIÓN DE CONEXIÓN      ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
            echo -ne "${CIAN}  ► Ingresa el host (ej: google.com): ${RESET}"
            read h
            if [ -n "$h" ]; then
                echo
                validar_conexion "$h"
            fi
            volver_menu
            ;;
            
        2)
            clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░      🔒 VERIFICACIÓN DE CERTIFICADO   ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
            echo -ne "${CIAN}  ► Ingresa el host (ej: google.com): ${RESET}"
            read h
            if [ -n "$h" ]; then
                echo
                validar_certificado "$h"
            fi
            volver_menu
            ;;
            
        3)
            clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░     🔍 ESCANEO DE MÚLTIPLES HOSTS     ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${CIAN}"
echo -e "   📋 Instrucciones:${RESET}"
echo -e "${GRIS}   • Escribe o pega cada host y presiona ENTER${RESET}"
echo -e "${GRIS}   • Cuando termines, escribe: ${BLANCO}FIN${GRIS} y presiona ENTER${RESET}"
echo -e ""
            
            > "$REPORTE_DIR/ultimo_reporte.txt"
            declare -a lista_hosts
            contador=0
            
            while true; do
                echo -ne "${CIAN}  ► Host $((contador + 1)): ${RESET}"
                read entrada
                entrada=$(echo "$entrada" | xargs)
                
                if [ "$entrada" = "FIN" ] || [ -z "$entrada" ] && [ $contador -gt 0 ]; then
                    break
                fi
                if [ -n "$entrada" ]; then
                    lista_hosts+=("$entrada")
                    contador=$((contador + 1))
                fi
            done
            
            total=${#lista_hosts[@]}
            if [ $total -eq 0 ]; then
                echo -e "${AMARILLO}  ℹ️  No se ingresaron hosts${RESET}"
                volver_menu
                continue
            fi
            
            echo -e ""
            echo -e "${VERDE}  ✅ $total hosts cargados — Iniciando escaneo...${RESET}"
            echo -e "${VERDE}  ════════════════════════════════════════════════════════════${RESET}\n"
            
            for h in "${lista_hosts[@]}"; do
                escanear_host "$h"
            done
            
            echo -e ""
            echo -e "${VERDE}  ════════════════════════════════════════════════════════════${RESET}"
            echo -e "${VERDE}  ✅ ESCANEO COMPLETADO — $total hosts procesados${RESET}"
            echo -e "${VERDE}  ════════════════════════════════════════════════════════════${RESET}"
            echo -e "${CIAN}  💾 El reporte está guardado automáticamente${RESET}"
            
            unset lista_hosts
            volver_menu
            ;;
            
                4)
            clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░      📄 ÚLTIMO REPORTE DE ESCANEO     ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
            
            if [ -f "$REPORTE_DIR/ultimo_reporte.txt" ]; then
                cat "$REPORTE_DIR/ultimo_reporte.txt"
            else
                echo -e "${AMARILLO}  ℹ️  No hay reporte disponible aún — Realiza un escaneo primero${RESET}"
            fi
            volver_menu
            ;;
            
        5)
            clear
echo -e "${VERDE}"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "   ░        💾 GUARDAR REPORTE             ░"
echo -e "   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo -e "${RESET}"
            echo -ne "${CIAN}  ► Nombre para el reporte: ${RESET}"
            read nombre
            guardar_reporte "$nombre"
            sleep 1.5
            volver_menu
            ;;
            
        6)
            listar_reportes
            ;;
            
        7)
            eliminar_reporte
            ;;
            
        8)
            ver_creditos
            ;;
            
        0)
            clear
echo -e "${VERDE}"
echo -e "      ¡Gracias por usar nuestra herramienta! 😊"
echo -e "${RESET}"
exit 0
;;

            
        *)
            echo -e "\n${ROJO}  ✖ Opción no válida — Inténtalo nuevamente${RESET}"
            sleep 1
            ;;
    esac
done
