#!/usr/bin/env bash
# get_www_ips.sh
# Genera ip_addresses_www.txt con formato:
# IP, HOSTNAME
# Resuelve: domain, www.domain, y si existe CNAME lo sigue.

set -euo pipefail

# Lista de dominios Chipotle
DOMAINS=(
  "chipotle.com"
  "marketing.chipotle.com"
  "btf.chipotle.com"
  "traceability.chipotle.com"
  "sftp.chipotle.com"
  "cloud.email.chipotle.com"
  "view.email.chipotle.com"
  "cafirefighters.chipotle.com"
  "socialportal.chipotle.com"
  "facilities.chipotle.com"
  "thankyou.chipotle.com"
)

OUT="ip_addresses_www.txt"

command -v dig >/dev/null || { echo "Necesitas 'dig'"; exit 1; }

: > "$OUT"

# Procesar cada dominio
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Procesando dominio: $DOMAIN" >&2
  
  hosts_to_check=("$DOMAIN" "www.${DOMAIN}")

  for h in "${hosts_to_check[@]}"; do
    # Si es CNAME, obtener el destino y usarlo también
    cname=$(dig +short CNAME "$h" | sed 's/\.$//')
    if [[ -n "$cname" ]]; then
      targets=("$h" "$cname")
    else
      targets=("$h")
    fi

    for t in "${targets[@]}"; do
      for ip in $(dig +short A "$t"); do
        echo "${ip}, ${t}" >> "$OUT"
      done
      for ip in $(dig +short AAAA "$t"); do
        echo "${ip}, ${t}" >> "$OUT"
      done
    done
  done
done

# si existe domain in DNS as A record via HTTP virtual host maybe different IPs—optativo: resolver common www aliases?
# Normalizar
sort -u "$OUT" -o "$OUT"

echo "Generado $OUT"
