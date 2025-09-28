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
while read host; do
    dig +short "$host" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> resolved_ips.txt
done < crt_hosts.txt

# 2. Búsqueda de dispositivos con Shodan CLI
echo "[+] Buscando en Shodan por organización..."
shodan search --fields ip_str,port "org:'Chipotle'" >> shodan_results.txt 2>/dev/null

echo "[+] Buscando en Shodan por bloques IP..."
while read ip_block; do
    shodan search --fields ip_str,port "net:$ip_block" >> shodan_results.txt 2>/dev/null
done < "$IPS_FILE"

# 3. Escaneo de puertos IoT con nmap
echo "[+] Escaneando puertos IoT con nmap..."
nmap -sS -p 22,23,161,443,9933 -iL "$IPS_FILE" -oG nmap_scan.txt >/dev/null 2>&1

# 4. Procesar y consolidar resultados
echo "[+] Consolidando resultados en $DEVICES_FILE..."

# Agregar hosts de crt.sh
cat crt_hosts.txt >> "$DEVICES_FILE"

# Agregar IPs resueltas
sort -u resolved_ips.txt >> "$DEVICES_FILE"

# Agregar resultados de Shodan
awk '{print $1}' shodan_results.txt | sort -u >> "$DEVICES_FILE"

# Agregar IPs activas de nmap
grep "Up" nmap_scan.txt | awk '{print $2}' >> "$DEVICES_FILE"

# Eliminar duplicados y limpiar formato
sort -u "$DEVICES_FILE" -o "$DEVICES_FILE"

# 5. Limpieza de archivos temporales
rm -f crt_hosts.txt resolved_ips.txt shodan_results.txt nmap_scan.txt

echo "[+] Finalizado. Se encontraron $(wc -l < $DEVICES_FILE) dispositivos/hosts únicos."