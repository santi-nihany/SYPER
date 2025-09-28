# Descargar un PDF del sitio (ejemplo)
wget https://www.chipotle.co.uk/content/dam/chipotle/pages/sustainability/us/2025/2023-Annual-Sustainability-Report-Update-w-Appx-2025.pdf

# Extraer metadatos con exiftool
exiftool 2023-Annual-Sustainability-Report-Update.pdf | grep -i "author\|creator\|producer"