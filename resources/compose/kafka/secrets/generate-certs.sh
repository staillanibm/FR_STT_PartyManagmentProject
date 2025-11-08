#!/bin/bash

# Configuration
PASSWORD="kafka123"
VALIDITY=365
KEYSTORE_FILE="kafka.keystore.jks"
TRUSTSTORE_FILE="kafka.truststore.jks"
CA_CERT="ca-cert"
CA_KEY="ca-key"

# Create password files
echo "$PASSWORD" > keystore_creds
echo "$PASSWORD" > key_creds
echo "$PASSWORD" > truststore_creds

echo "=== Génération de l'autorité de certification (CA) ==="
openssl req -new -x509 -keyout $CA_KEY -out $CA_CERT -days $VALIDITY -subj "/CN=KafkaCA" -passout pass:$PASSWORD

echo "=== Création du keystore ==="
keytool -genkey -noprompt \
  -alias kafka \
  -dname "CN=localhost, OU=Kafka, O=MyOrg, L=Paris, S=IDF, C=FR" \
  -keystore $KEYSTORE_FILE \
  -keyalg RSA \
  -storepass $PASSWORD \
  -keypass $PASSWORD \
  -validity $VALIDITY \
  -storetype JKS \
  -ext SAN=DNS:localhost,DNS:kafka,IP:127.0.0.1

echo "=== Export de la certificate signing request (CSR) ==="
keytool -certreq \
  -alias kafka \
  -keystore $KEYSTORE_FILE \
  -file cert-file \
  -storepass $PASSWORD

cat > san.cnf <<'EOF'
[ v3_req ]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ alt_names ]
DNS.1 = kafka
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

echo "=== Signature du certificat avec le CA ==="
openssl x509 -req -in cert-file -CA $CA_CERT -CAkey $CA_KEY \
  -out cert-signed -days $VALIDITY -CAcreateserial -passin pass:$PASSWORD \
  -extfile san.cnf -extensions v3_req

echo "=== Import du certificat CA dans le keystore ==="
keytool -import -noprompt \
  -alias CARoot \
  -file $CA_CERT \
  -keystore $KEYSTORE_FILE \
  -storepass $PASSWORD

echo "=== Import du certificat signé dans le keystore ==="
keytool -import -noprompt \
  -alias kafka \
  -file cert-signed \
  -keystore $KEYSTORE_FILE \
  -storepass $PASSWORD

echo "=== Création du truststore ==="
keytool -import -noprompt \
  -alias CARoot \
  -file $CA_CERT \
  -keystore $TRUSTSTORE_FILE \
  -storepass $PASSWORD

echo "=== Nettoyage des fichiers temporaires ==="
rm cert-file cert-signed ca-cert.srl

echo "=== Certificats générés avec succès ==="
ls -lh *.jks
