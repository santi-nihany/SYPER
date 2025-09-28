# 1. Resolver los subdominios a direcciones IP
for domain in $(cat domain.txt); do
    dig $domain +short >> ips_temp.txt
done
sort -u ips_temp.txt -o ip_addresses.txt

# 2. Escanear puertos en las IPs encontradas (usando nmap)
# Este comando escanea los 1000 puertos más comunes de forma rápida.
nmap -sS -T4 -iL ip_addresses.txt -oG nmap_scan_results.txt

# 3. Formatear la salida para devices.txt: [IP] - [Puertos abiertos]
awk '/Up$/ {print $2 " - Puertos abiertos: " $4}' nmap_scan_results.txt | sed 's/\/open\/tcp\//\/tcp, /g' > devices.txt