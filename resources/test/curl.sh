source .env_dev

ACCESS_TOKEN=$(curl -s -X POST "${TOKEN_URL}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -d "grant_type=client_credentials&scope=${SCOPE}" | jq -r '.access_token')

[ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ] || { echo "Erreur: Token invalide"; exit 1; }

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/parties" \
  -H "webhook_key: ${API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{
    "name": "Bob",
    "type": "individual",
    "status": "active"
  }')

HTTP_STATUS=$(echo "${RESPONSE}" | tail -n1)
RESPONSE_BODY=$(echo "${RESPONSE}" | sed '$d')

echo "HTTP status : ${HTTP_STATUS}"
echo "Response : "
echo ${RESPONSE_BODY} | jq

# Extract values
ID=$(echo "$RESPONSE_BODY" | jq -r '.id')
NAME=$(echo "$RESPONSE_BODY" | jq -r '.name')
TYPE=$(echo "$RESPONSE_BODY" | jq -r '.type')
STATUS=$(echo "$RESPONSE_BODY" | jq -r '.status')
CREATION_DT=$(echo "$RESPONSE_BODY" | jq -r '.creationDateTime')
UPDATE_DT=$(echo "$RESPONSE_BODY" | jq -r '.updateDateTime')

# Tests
UUID_REGEX="^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

[ "$HTTP_STATUS" -eq 201 ] && echo "✅ HTTP Status 201" || echo "❌ HTTP Status $HTTP_STATUS"
[[ "$ID" =~ $UUID_REGEX ]] && echo "✅ ID is UUID: $ID" || echo "❌ Invalid ID: $ID"
[ "$NAME" = "Bob" ] && echo "✅ name = Bob" || echo "❌ name = $NAME"
[ "$TYPE" = "individual" ] && echo "✅ type = individual" || echo "❌ type = $TYPE"
[ "$STATUS" = "active" ] && echo "✅ status = active" || echo "❌ status = $STATUS"
[ -n "$CREATION_DT" ] && [ "$CREATION_DT" != "null" ] && echo "✅ creationDateTime: $CREATION_DT" || echo "❌ creationDateTime empty"
[ -n "$UPDATE_DT" ] && [ "$UPDATE_DT" != "null" ] && echo "✅ updateDateTime: $UPDATE_DT" || echo "❌ updateDateTime empty"
