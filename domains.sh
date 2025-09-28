# Enumeración pasiva con subfinder
subfinder -d chipotle.com -silent > subdominios_temp.txt

# Ordenar y eliminar duplicados
sort -u subdominios_temp.txt -o domains.txt