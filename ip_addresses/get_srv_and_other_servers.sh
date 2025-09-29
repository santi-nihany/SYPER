#!/usr/bin/env bash
# get_srv_and_other_servers.sh
# Genera ip_addresses_srv.txt con:
# IP, SRV_NAME, TARGET_HOST, PORT, PROTOCOL
# Además, si existe devices.txt en el directorio, lo integra (esperando formatos FQDN o IP,PUERTO,SERVICIO,DOM)

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

OUT="ip_addresses_srv.txt"
TMPSRV=$(mktemp)

command -v dig >/dev/null || { echo "Necesitas 'dig'"; exit 1; }
command -v awk >/dev/null || { echo "Necesitas 'awk'"; exit 1; }

: > "$OUT"

# Lista de prefijos SRV comunes a consultar — puedes ampliar según tus necesidades
SRV_PREFS=(
  "_sip._tcp"
  "_sip._udp"
  "_xmpp-client._tcp"
  "_xmpp-server._tcp"
  "_ldap._tcp"
  "_http._tcp"
  "_https._tcp"
  "_caldav._tcp"
  "_carddav._tcp"
  "_smtp._tcp"
)

# Procesar cada dominio
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Procesando dominio: $DOMAIN" >&2
  
  for pref in "${SRV_PREFS[@]}"; do
    fq="${pref}.${DOMAIN}"
    # obtener SRV records
    dig +short SRV "$fq" | sed 's/\.$//' >> "$TMPSRV" || true
  done

  # Parsear SRV (formato: priority weight port target)
  if [[ -s $TMPSRV ]]; then
    while read -r line; do
      # ejemplo: "10 60 5060 sipserver.example.com."
      prio=$(awk '{print $1}' <<<"$line")
      weight=$(awk '{print $2}' <<<"$line")
      port=$(awk '{print $3}' <<<"$line")
      target=$(awk '{print $4}' <<<"$line" | sed 's/\.$//')
      # resolver IPs para target
      for ip in $(dig +short A "$target"); do
        echo "${ip}, SRV, ${target}, ${port}, ${prio}, ${weight}" >> "$OUT"
      done
      for ip in $(dig +short AAAA "$target"); do
        echo "${ip}, SRV, ${target}, ${port}, ${prio}, ${weight}" >> "$OUT"
      done
    done < "$TMPSRV"
  else
    echo "# No se encontraron registros SRV comunes para $DOMAIN" >> "$OUT"
  fi
done

# Si existe devices.txt integrarlo (suponiendo formato IP,PUERTO,SERVICIO,DOM)
if [[ -f "devices.txt" ]]; then
  echo "# Integrando devices.txt" >> "$OUT"
  # limpiar cruft y añadir
  awk -F, 'NF>=1 {print $0}' devices.txt >> "$OUT"
fi

# (opcional) Si tienes nmap y quieres detectar servicios en IPs encontradas, descomenta la siguiente sección
# REQUIERE permiso y uso responsable.
: <<'NMAPBLOCK'
if command -v nmap >/dev/null 2>&1; then
  echo "# nmap found — escaneo ligero de puertos (Top 100) — Solo si estás autorizado" >&2
  IPS=$(awk -F, '/^[0-9]/ {print $1}' "$OUT" | sort -u)
  for ip in $IPS; do
    echo "Escaneando $ip ..." >&2
    nmap -Pn --top-ports 100 -oG - "$ip" | awk '/\/open\// {print $2 ", nmap_open," $5}' >> "$OUT"
  done
fi
NMAPBLOCK

# Normalizar/ordenar
sort -u "$OUT" -o "$OUT"

echo "Generado $OUT"
rm -f "$TMPSRV"
