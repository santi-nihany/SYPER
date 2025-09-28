# Descargar un PDF del sitio (ejemplo)
wget https://www.chipotle.com/path/to/2023-Annual-Sustainability-Report-Update.pdf

# Extraer metadatos con exiftool
exiftool 2023-Annual-Sustainability-Report-Update.pdf | grep -i "author\|creator\|producer"