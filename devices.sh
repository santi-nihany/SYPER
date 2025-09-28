#!/bin/bash

# Script limpio para buscar servicios de chipotle.com usando solo Shodan
# Output: IP,PUERTO,SERVICIO,DOMINIO en archivo shodan.txt

# Configuración
DOMAIN="chipotle.com"
OUTPUT_FILE="shodan.txt"

# Verificar que la API key de Shodan esté configurada
if [ -z "$SHODAN_API_KEY" ]; then
    echo "[-] Error: SHODAN_API_KEY no está configurada"
    echo "[-] Configure su API key con: export SHODAN_API_KEY='su_api_key'"
    exit 1
fi

# Inicializar Shodan CLI
shodan init "$SHODAN_API_KEY"

# Limpiar archivo de resultados
> "$OUTPUT_FILE"

echo "[+] Iniciando búsqueda de servicios para $DOMAIN usando Shodan"

# Buscar servicios directamente con el dominio en Shodan
echo "[+] Buscando servicios asociados a $DOMAIN en Shodan..."

# Usar shodan search para buscar servicios del dominio
shodan_output=$(shodan search "hostname:$DOMAIN" --fields ip_str,port,product,hostnames 2>/dev/null)

if [ -n "$shodan_output" ]; then
    echo "$shodan_output" | while read line; do
        if [ -n "$line" ] && [[ "$line" != "" ]]; then
            # Parsear la línea usando tabulación como separador
            # Formato: IP<TAB>PORT<TAB>PRODUCT<TAB>HOSTNAMES
            ip=$(echo "$line" | cut -f1)
            port=$(echo "$line" | cut -f2)
            product=$(echo "$line" | cut -f3)
            hostnames=$(echo "$line" | cut -f4)
            
            # Determinar el servicio basado en el puerto (prioridad) y producto
            if [[ $port == "80" ]]; then
                service="http"
            elif [[ $port == "443" ]]; then
                service="https"
            elif [[ $port == "22" ]] || [[ $product == *"ssh"* ]]; then
                service="ssh"
            elif [[ $port == "23" ]] || [[ $product == *"telnet"* ]]; then
                service="telnet"
            elif [[ $port == "161" ]] || [[ $product == *"snmp"* ]]; then
                service="snmp"
            elif [[ $port == "9933" ]]; then
                service="custom"
            elif [[ $port == "25" ]] || [[ $product == *"smtp"* ]]; then
                service="smtp"
            elif [[ $port == "53" ]] || [[ $product == *"dns"* ]]; then
                service="dns"
            elif [[ $port == "21" ]] || [[ $product == *"ftp"* ]]; then
                service="ftp"
            elif [[ $port == "110" ]] || [[ $product == *"pop3"* ]]; then
                service="pop3"
            elif [[ $port == "143" ]] || [[ $product == *"imap"* ]]; then
                service="imap"
            elif [[ $port == "993" ]] || [[ $product == *"imaps"* ]]; then
                service="imaps"
            elif [[ $port == "995" ]] || [[ $product == *"pop3s"* ]]; then
                service="pop3s"
            elif [[ $port == "587" ]] || [[ $product == *"smtp"* ]]; then
                service="smtp-submission"
            elif [[ $port == "465" ]] || [[ $product == *"smtps"* ]]; then
                service="smtps"
            elif [[ $port == "8443" ]]; then
                service="https-alt"
            else
                # Usar el producto como servicio, o "unknown" si está vacío
                if [ -n "$product" ] && [[ "$product" != "-" ]]; then
                    service=$(echo "$product" | tr '[:upper:]' '[:lower:]' | cut -d' ' -f1)
                else
                    service="unknown"
                fi
            fi
            
            # Determinar el dominio - usar hostnames si está disponible, sino null
            if [ -n "$hostnames" ] && [[ "$hostnames" != "-" ]] && [[ "$hostnames" != "" ]]; then
                # Tomar el primer hostname disponible
                domain=$(echo "$hostnames" | awk '{print $1}')
            else
                domain="null"
            fi
            
            # Escribir resultado en el formato requerido: IP,PUERTO,SERVICIO,DOMINIO
            echo "$ip,$port,$service,$domain" >> "$OUTPUT_FILE"
            echo "[+] Servicio encontrado: $ip:$port ($service) - $domain"
        fi
    done
    
    # Verificar si se encontraron resultados
    if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        # Eliminar duplicados
        sort -u "$OUTPUT_FILE" -o "${OUTPUT_FILE}.tmp"
        mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
        
        echo "[+] Se encontraron $(wc -l < "$OUTPUT_FILE") servicios únicos"
        echo "[+] Resultados guardados en $OUTPUT_FILE"
        
        # Mostrar resumen de resultados
        echo ""
        echo "[+] Resumen de servicios encontrados:"
        echo "IP,PUERTO,SERVICIO,DOMINIO"
        cat "$OUTPUT_FILE"
    else
        echo "[-] No se encontraron servicios activos para $DOMAIN"
        echo "IP,PUERTO,SERVICIO,DOMINIO" > "$OUTPUT_FILE"
    fi
else
    echo "[-] No se pudieron obtener resultados de Shodan para $DOMAIN"
    echo "IP,PUERTO,SERVICIO,DOMINIO" > "$OUTPUT_FILE"
fi

echo ""
echo "[+] Búsqueda completada. Ver $OUTPUT_FILE para detalles."