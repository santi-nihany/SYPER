# Enumeración pasiva con subfinder
subfinder -d chipotle.com -silent > subdominios_temp.txt
subfinder -d chipotle.co.uk -silent >> subdominios_temp.txt

# Enumeración activa con amass (más lenta pero profunda)
amass enum -passive -d chipotle.com >> subdominios_temp.txt
amass enum -passive -d chipotle.co.uk >> subdominios_temp.txt

# Ordenar y eliminar duplicados
sort -u subdominios_temp.txt -o domains.txt