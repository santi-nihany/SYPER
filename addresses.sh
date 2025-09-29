#!/usr/bin/env bash
set -euo pipefail

# Configurables
INPUT_GLOB="devices.txt"
MIN_IPS=10
OUTFILE="shodan_cli_results.csv"
FIELDS="ip_str,port,transport,product,version,org,os,data"  # data ~ banner/raw

shodan init "$SHODAN_API_KEY"

# Comprobaciones
command -v shodan >/dev/null 2>&1 || { echo "Instala la CLI de shodan (pip install shodan) y configura con 'shodan init YOUR_KEY'"; exit 1; }
shopt -s nullglob
files=( $INPUT_GLOB )
if [ ${#files[@]} -eq 0 ]; then
  echo "No se encontraron archivos con patrón: ${INPUT_GLOB}"; exit 1
fi

# Extraer IPs únicas (A.B.C.D) y tomar al menos MIN_IPS
ips=( $(grep -Eo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' ${files[@]} | sort -u | head -n ${MIN_IPS}) )
if [ ${#ips[@]} -lt ${MIN_IPS} ]; then
  echo "Advertencia: se encontraron solo ${#ips[@]} IP(s). Se requiere al menos ${MIN_IPS}."
fi

# Cabecera CSV
echo "ip,port/proto,product,version,org,city,country,domain" > "${OUTFILE}"

# Función para procesar una IP con shodan CLI
process_ip() {
  local ip="$1"
  
  # Obtener información completa del host
  local host_info=$(shodan host "${ip}" 2>/dev/null)
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Extraer información básica del host
  local org=$(echo "$host_info" | grep "Organization:" | cut -d: -f2- | sed 's/^[ \t]*//')
  local city=$(echo "$host_info" | grep "City:" | cut -d: -f2- | sed 's/^[ \t]*//')
  local country=$(echo "$host_info" | grep "Country:" | cut -d: -f2- | sed 's/^[ \t]*//')
  local domain=$(echo "$host_info" | grep "Hostnames:" | cut -d: -f2- | sed 's/^[ \t]*//')
  
  # Función para limpiar texto para CSV
  clean() {
    echo "$1" | tr '\n' ' ' | sed 's/,/;/g' | sed 's/^[ \t]*//;s/[ \t]*$//'
  }
  
  # Procesar cada puerto desde la información detallada
  echo "$host_info" | awk '/^Ports:/,/^$/' | grep -E '^\s+[0-9]+/tcp' | while read -r line; do
    # Extraer puerto, protocolo y producto de la línea
    port=$(echo "$line" | sed 's/^[ \t]*\([0-9]*\)\/.*/\1/')
    transport=$(echo "$line" | sed 's/^[ \t]*[0-9]*\/\([a-z]*\).*/\1/')
    product=$(echo "$line" | sed 's/^[ \t]*[0-9]*\/[a-z]*[ \t]*//' | sed 's/[ \t]*$//')
    
    # Si no hay producto en la línea principal, buscar en líneas siguientes
    if [ -z "$product" ]; then
      # Buscar en las líneas que siguen a este puerto
      port_section=$(echo "$host_info" | sed -n "/^\s*${port}\/${transport}/,/^\s*[0-9]/p")
      product=$(echo "$port_section" | grep -v "^\s*[0-9]" | grep -v "^\s*$" | grep -v "HTTP title\|Cert\|SSL" | head -n 1 | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
    fi
    
    # Separar producto y versión si están juntos (formato: "producto (versión)")
    version=""
    if echo "$product" | grep -q "(" && echo "$product" | grep -q ")"; then
      # Extraer versión entre paréntesis
      version=$(echo "$product" | sed 's/.*(\([^)]*\)).*/\1/')
      # Remover la versión del producto
      product=$(echo "$product" | sed 's/ (.*)//')
    fi
    
    # Limpiar campos para CSV
    product_c=$(clean "${product:-}")
    version_c=$(clean "${version:-}")
    org_c=$(clean "${org:-}")
    city_c=$(clean "${city:-}")
    country_c=$(clean "${country:-}")
    domain_c=$(clean "${domain:-}")
    
    if [ -n "$port" ] && [ -n "$transport" ]; then
      printf "%s,%s,%s,%s,%s,%s,%s,%s\n" "$ip" "${port}/${transport}" "$product_c" "$version_c" "$org_c" "$city_c" "$country_c" "$domain_c" >> "${OUTFILE}"
    fi
  done
}

# Escanear cada IP
for ip in "${ips[@]}"; do
  echo "Consultando Shodan para ${ip}..."
  process_ip "${ip}" || echo "Error procesando ${ip} (continuando)..."
done

echo "Resultados guardados en: ${OUTFILE}"
