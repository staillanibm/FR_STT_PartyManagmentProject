source .env_dev

kcat -P \
  -b "${BOOTSTRAP_SERVERS}" \
  -X client.id=test-client \
  -X acks="1" \
  -X security.protocol="SASL_SSL" \
  -X sasl.mechanisms="PLAIN" \
  -X sasl.username="${SASL_USERNAME}" \
  -X sasl.password="${SASL_PASSWORD}" \
  -X enable.ssl.certificate.verification=false \
  -t "${TOPIC}" \
  ./event-sample-valid.json

kcat -P \
  -b "${BOOTSTRAP_SERVERS}" \
  -X client.id=test-client \
  -X acks="1" \
  -X security.protocol="SASL_SSL" \
  -X sasl.mechanisms="PLAIN" \
  -X sasl.username="${SASL_USERNAME}" \
  -X sasl.password="${SASL_PASSWORD}" \
  -X enable.ssl.certificate.verification=false \
  -t "${TOPIC}" \
  ./event-sample-invalid.json