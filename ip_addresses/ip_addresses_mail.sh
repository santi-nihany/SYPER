#!/usr/bin/env bash
# get_mail_ips.sh
# Genera ip_addresses_mail.txt con formato:
# IP, PRIORITY, MAIL_HOST
# Ej: 192.0.2.1, 10, mx1.example.com

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

OUT="ip_addresses_mail.txt"
TMPMX=$(mktemp)

command -v dig >/dev/null || { echo "Necesitas 'dig' (dnsutils/bind-utils)"; exit 1; }
command -v host >/dev/null || { echo "Necesitas 'host'"; exit 1; }

# Vaciar/crear fichero
: > "$OUT"

# Procesar cada dominio
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Procesando dominio: $DOMAIN" >&2
  
  # Obtener MX (priority host)
  dig +short MX "$DOMAIN" | sort -n > "$TMPMX"

  if [[ ! -s $TMPMX ]]; then
    echo "# No se encontraron registros MX para $DOMAIN" >> "$OUT"
    continue
  fi

  while read -r line; do
    # línea: "10 mx1.example.com."
    prio=$(awk '{print $1}' <<<"$line")
    hostn=$(awk '{print $2}' <<<"$line" | sed 's/\.$//')
    # resolver A/AAAA
    for ip in $(dig +short A "$hostn"); do
      echo "${ip}, ${prio}, ${hostn}" >> "$OUT"
    done
    for ip in $(dig +short AAAA "$hostn"); do
      echo "${ip}, ${prio}, ${hostn}" >> "$OUT"
    done
  done < "$TMPMX"
done

# Normalizar/ordenar/unique
awk -F, '{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $0}' "$OUT" | sort -t, -k1,1 -u > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"

echo "Generado $OUT"
rm -f "$TMPMX"
