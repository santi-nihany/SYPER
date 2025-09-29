#!/usr/bin/env bash
# get_dns_ips_and_axfr.sh
# Genera ip_addresses_dns.txt con formato:
# IP, NS_HOST, AXFR_ALLOWED(yes/no)
# También guarda los hosts NS en ns_hosts.txt

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

OUT="ip_addresses_dns.txt"
NSLIST="ns_hosts.txt"
TMPNS=$(mktemp)

command -v dig >/dev/null || { echo "Necesitas 'dig'"; exit 1; }
command -v host >/dev/null || { echo "Necesitas 'host'"; exit 1; }

: > "$OUT"
: > "$NSLIST"

# Procesar cada dominio
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Procesando dominio: $DOMAIN" >&2
  
  # obtener NS
  dig +short NS "$DOMAIN" | sed 's/\.$//' > "$TMPNS"

  if [[ ! -s $TMPNS ]]; then
    echo "# No se encontraron registros NS para $DOMAIN" >> "$OUT"
    continue
  fi

  while read -r ns; do
    echo "$ns" >> "$NSLIST"
    # resolver IPs
    for ip in $(dig +short A "$ns"); do
      echo "${ip}, ${ns}, unknown" >> "$OUT"
    done
    for ip in $(dig +short AAAA "$ns"); do
      echo "${ip}, ${ns}, unknown" >> "$OUT"
    done
  done < "$TMPNS"

  # Intentar AXFR (intento por cada servidor NS; si AXFR devuelve SOA u otros RR -> allowed)
  while read -r ns; do
    echo "Checking zone transfer on $ns for $DOMAIN ..." >&2
    axfr=$(dig @"$ns" AXFR "$DOMAIN" +timeout=5 +tries=1 2>/dev/null)
    if [[ -n "$axfr" ]] && ! grep -q "transfer failed" <<<"$axfr"; then
      # Si contiene al menos una línea con "IN" o "SOA" consideramos permitido
      if grep -q "SOA\|IN" <<<"$axfr"; then
        # marcar los IPs previamente guardados como AXFR yes
        awk -v ns="$ns" -F, 'BEGIN{OFS=","} $2 ~ ns { $3=" yes"; print } $2 !~ ns { print }' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
        # opcional: guardar dump de AXFR
        safe_name="axfr_${ns//./_}_${DOMAIN//./_}.zone"
        printf "%s\n" "$axfr" > "$safe_name"
        echo "AXFR allowed on $ns for $DOMAIN — se guardó $safe_name" >&2
        continue
      fi
    fi
    # si llegamos aquí, marcar no
    awk -v ns="$ns" -F, 'BEGIN{OFS=","} $2 ~ ns { $3=" no"; print } $2 !~ ns { print }' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
  done < "$TMPNS"
done

# ordenar y normalizar
sort -u "$OUT" -o "$OUT"

echo "Generado $OUT y $NSLIST"
rm -f "$TMPNS"
