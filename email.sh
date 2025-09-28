# Ejemplo de consulta usando curl y jq para parsear JSON
curl -s "https://api.hunter.io/v2/domain-search?domain=chipotle.com&api_key=$HUNTER_API_KEY" | jq -r '.data.emails[].value' >> email.txt