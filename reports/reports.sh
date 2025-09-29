#!/bin/bash

# Configuración
DOMAIN="chipotle.com"
ORGANIZATION="Chipotle Mexican Grill"
REPORTS_FILE="reports.txt"

echo "# Contactos de Reporte - $ORGANIZATION" > $REPORTS_FILE
echo "# Generado: $(date)" >> $REPORTS_FILE
echo "" >> $REPORTS_FILE

# 1. Contactos de dominio (WHOIS)
echo "=== CONTACTOS DE DOMINIO ===" >> $REPORTS_FILE
echo "## Gestión técnica y administrativa del dominio" >> $REPORTS_FILE

whois $DOMAIN | grep -iE "registrar abuse contact email:|abuse email:|abuse@|abuse-contact:" | head -5 | while read line; do
    echo "Tipo: Abuse de Dominio" >> $REPORTS_FILE
    echo "Contacto: $line" >> $REPORTS_FILE
    echo "Canal: Email (WHOIS)" >> $REPORTS_FILE
    echo "Propósito: Reporte de actividades maliciosas relacionadas con el dominio" >> $REPORTS_FILE
    echo "---" >> $REPORTS_FILE
done

# 2. Contactos de IPs (Bloques de red)
echo "" >> $REPORTS_FILE
echo "=== CONTACTOS DE BLOQUES IP ===" >> $REPORTS_FILE

# Consultar whois para cada bloque IP conocido
if [ -f "ip_blocks.txt" ]; then
    grep -E "^[0-9]" ip_blocks.txt | head -3 | while read cidr; do
        ip=$(echo $cidr | cut -d'/' -f1)
        echo "## Bloque: $cidr" >> $REPORTS_FILE
        
        whois $ip | grep -iE "org-name:|netname:|abuse-mailbox:|abuse@|abuse contact:" | head -3 | while read line; do
            echo "Información: $line" >> $REPORTS_FILE
        done
        
        whois $ip | grep -i "abuse" | grep -i "email" | head -1 | while read abuse_email; do
            echo "Tipo: Abuse de Red" >> $REPORTS_FILE
            echo "Contacto: $abuse_email" >> $REPORTS_FILE
            echo "Canal: Email" >> $REPORTS_FILE
            echo "Propósito: Reporte de actividades maliciosas desde IPs del bloque" >> $REPORTS_FILE
        done
        echo "---" >> $REPORTS_FILE
    done
fi

# 3. Contactos de seguridad de la organización
echo "" >> $REPORTS_FILE
echo "=== CONTACTOS DE SEGURIDAD DE LA ORGANIZACIÓN ===" >> $REPORTS_FILE

# Buscar en políticas de seguridad y página principal
echo "Tipo: Seguridad/Abuse Organizacional" >> $REPORTS_FILE
echo "Contacto: privacy@chipotle.com" >> $REPORTS_FILE
echo "Canal: Email" >> $REPORTS_FILE
echo "Propósito: Reporte de problemas de privacidad y seguridad de datos" >> $REPORTS_FILE
echo "Fuente: Política de Privacidad del sitio web" >> $REPORTS_FILE
echo "---" >> $REPORTS_FILE

echo "Tipo: Accesibilidad Web" >> $REPORTS_FILE
echo "Contacto: ADAWebsite@chipotle.com" >> $REPORTS_FILE
echo "Canal: Email" >> $REPORTS_FILE
echo "Propósito: Reporte de problemas de accesibilidad en el sitio web" >> $REPORTS_FILE
echo "Fuente: Página de Accesibilidad" >> $REPORTS_FILE
echo "---" >> $REPORTS_FILE

# 4. Contactos de Bug Bounty
echo "" >> $REPORTS_FILE
echo "=== PROGRAMA BUG BOUNTY ===" >> $REPORTS_FILE
echo "Tipo: Reporte de Vulnerabilidades" >> $REPORTS_FILE
echo "Plataforma: Bugcrowd" >> $REPORTS_FILE
echo "URL: https://bugcrowd.com/chipotle" >> $REPORTS_FILE
echo "Canal: Plataforma Bugcrowd" >> $REPORTS_FILE
echo "Propósito: Reporte formal de vulnerabilidades de seguridad" >> $REPORTS_FILE
echo "---" >> $REPORTS_FILE

echo "" >> $REPORTS_FILE
echo "# Nota: Para reportes de seguridad, usar el programa Bugcrowd como canal principal"
echo "# Contactos WHOIS son para reportes de red/dominio a nivel de proveedor"

echo "[+] Reporte generado en: $REPORTS_FILE"