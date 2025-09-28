#!/bin/bash

# Configuración
DOMAIN="chipotle.com"
IPS_FILE="ip_blocks.txt"
DEVICES_FILE="devices.txt"


shodan init "$SHODAN_API_KEY"

# Limpiar archivo de resultados
> "$DEVICES_FILE"

echo "[+] Iniciando descubrimiento de dispositivos para $DOMAIN"

# 1. Descubrimiento de subdominios y hosts con crt.sh
echo "[+] Buscando subdominios en crt.sh..."
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > crt_hosts.txt

echo "[+] Resolviendo direcciones IP de subdominios..."
if [ -f "crt_hosts.txt" ] && [ -s "crt_hosts.txt" ]; then
    while read host; do
        dig +short "$host" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> resolved_ips.txt
    done < crt_hosts.txt
else
    echo "[-] No hay subdominios para resolver"
    touch resolved_ips.txt
fi

# 2. Búsqueda de dispositivos con Shodan CLI
echo "[+] Buscando en Shodan por organización..."
shodan search --fields ip_str,port "org:'Chipotle'" >> shodan_results.txt 2>/dev/null

echo "[+] Buscando en Shodan por bloques IP..."
if [ -f "$IPS_FILE" ] && [ -s "$IPS_FILE" ]; then
    while read ip_block; do
        shodan search --fields ip_str,port "net:$ip_block" >> shodan_results.txt 2>/dev/null
    done < "$IPS_FILE"
else
    echo "[-] Archivo $IPS_FILE no existe o está vacío, saltando búsqueda por bloques IP..."
fi

# 3. Escaneo de puertos IoT con nmap
echo "[+] Escaneando puertos IoT con nmap..."
if [ -f "$IPS_FILE" ] && [ -s "$IPS_FILE" ]; then
    # Extraer rangos de IP del formato NetRange y crear archivo temporal para nmap
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ - [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$IPS_FILE" > nmap_targets.txt
    if [ -s "nmap_targets.txt" ]; then
        nmap -sT -p 22,23,161,443,9933 -iL nmap_targets.txt -oG nmap_scan.txt >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "[-] Error en escaneo nmap, continuando sin resultados de nmap..."
            touch nmap_scan.txt  # Crear archivo vacío para evitar errores
        fi
        rm -f nmap_targets.txt
    else
        echo "[-] No se encontraron rangos de IP válidos en $IPS_FILE"
        touch nmap_scan.txt  # Crear archivo vacío para evitar errores
    fi
else
    echo "[-] Archivo $IPS_FILE no existe o está vacío, saltando escaneo nmap..."
    touch nmap_scan.txt  # Crear archivo vacío para evitar errores
fi

# 4. Procesar y consolidar resultados
echo "[+] Consolidando resultados en $DEVICES_FILE..."

# Agregar hosts de crt.sh
if [ -f "crt_hosts.txt" ] && [ -s "crt_hosts.txt" ]; then
    cat crt_hosts.txt >> "$DEVICES_FILE"
fi

# Agregar IPs resueltas
if [ -f "resolved_ips.txt" ] && [ -s "resolved_ips.txt" ]; then
    sort -u resolved_ips.txt >> "$DEVICES_FILE"
fi

# Agregar resultados de Shodan
if [ -f "shodan_results.txt" ] && [ -s "shodan_results.txt" ]; then
    awk '{print $1}' shodan_results.txt | sort -u >> "$DEVICES_FILE"
fi

# Agregar IPs activas de nmap
if [ -f "nmap_scan.txt" ] && [ -s "nmap_scan.txt" ]; then
    grep "Up" nmap_scan.txt | awk '{print $2}' >> "$DEVICES_FILE"
fi

# Eliminar duplicados y limpiar formato
sort -u "$DEVICES_FILE" -o "$DEVICES_FILE"

# 5. Limpieza de archivos temporales
# rm -f crt_hosts.txt resolved_ips.txt shodan_results.txt nmap_scan.txt

echo "[+] Finalizado. Se encontraron $(wc -l < $DEVICES_FILE) dispositivos/hosts únicos."