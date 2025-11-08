# Kafka KRaft Commands with SASL_SSL + PLAIN

## 1. SSL Certificate Generation

```bash
cd secrets
chmod +x generate-certs.sh
./generate-certs.sh
cd ..
```

The following certificates will be created:
- `kafka.keystore.jks`: Keystore containing the private key and server certificate
- `kafka.truststore.jks`: Truststore containing the CA certificate
- Credential files: `keystore_creds`, `key_creds`, `truststore_creds`

## 2. Starting the Kafka Cluster

```bash
docker-compose up -d
```

## 3. Status Verification

```bash
docker-compose ps
docker logs kafka
```

## 4. Creating a Topic

```bash
docker exec -it kafka kafka-topics \
  --create \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --command-config /etc/kafka/secrets/admin-client.properties \
  --partitions 3 \
  --replication-factor 1
```

## 5. Listing Topics

```bash
docker exec -it kafka kafka-topics \
  --list \
  --bootstrap-server localhost:9092 \
  --command-config /etc/kafka/secrets/admin-client.properties
```

## 6. Describing a Topic

```bash
docker exec -it kafka kafka-topics \
  --describe \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --command-config /etc/kafka/secrets/admin-client.properties
```

## 7. Producing Messages (Producer)

```bash
docker exec -it kafka kafka-console-producer \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --producer.config /etc/kafka/secrets/producer-client.properties
```

Type your messages then press Ctrl+C to exit.

Or with inline messages:
```bash
docker exec -i kafka kafka-console-producer \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --producer.config /etc/kafka/secrets/producer-client.properties <<EOF
Message 1
Message 2
Message 3
EOF
```

## 8. Consuming Messages (Consumer)

```bash
docker exec -it kafka kafka-console-consumer \
  --topic test-topic \
  --from-beginning \
  --bootstrap-server localhost:9092 \
  --consumer.config /etc/kafka/secrets/consumer-client.properties
```

Press Ctrl+C to exit.

Or to consume a limited number of messages:
```bash
docker exec kafka kafka-console-consumer \
  --topic test-topic \
  --offset latest \
  --max-messages 100 \
  --bootstrap-server localhost:9092 \
  --consumer.config /etc/kafka/secrets/consumer-client.properties
```

## 9. Checking Consumer Groups

```bash
docker exec -it kafka kafka-consumer-groups \
  --list \
  --bootstrap-server localhost:9092 \
  --command-config /etc/kafka/secrets/admin-client.properties
```

## 10. Broker Information

```bash
docker exec -it kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092 \
  --command-config /etc/kafka/secrets/admin-client.properties
```

## 11. Stopping the Cluster

```bash
docker-compose down
```

## 12. Complete Shutdown and Cleanup (including volumes)

```bash
docker-compose down -v
```

## SASL/SSL Configuration

### Client Configuration Files Created:

- `/etc/kafka/secrets/admin-client.properties`: Configuration for admin user
- `/etc/kafka/secrets/producer-client.properties`: Configuration for producer user
- `/etc/kafka/secrets/consumer-client.properties`: Configuration for consumer user

### Configured Users:

- **admin** / admin-secret: Administrator with all rights
- **producer** / producer-secret: User for message production
- **consumer** / consumer-secret: User for message consumption

### Configured Listeners:

- **Port 9092**: SASL_SSL (SASL authentication + SSL encryption)
- **Port 9093**: PLAINTEXT (no authentication, for internal use)
- **Port 9094**: CONTROLLER (for internal KRaft communication)

## Important Notes

1. Generated SSL certificates are self-signed and valid for 365 days
2. KRaft mode does not require ZooKeeper
3. The cluster ID used is: `MkU3OEVBNTcwNTJENDM2Qk`
4. Data persists in the Docker volume `kafka-data`
5. For production use, change passwords in JAAS files

## Troubleshooting

### View logs in real-time:
```bash
docker logs -f kafka
```

### Connect to the container:
```bash
docker exec -it kafka bash
```

### Verify certificates:
```bash
keytool -list -v -keystore secrets/kafka.keystore.jks -storepass kafka123
keytool -list -v -keystore secrets/kafka.truststore.jks -storepass kafka123
```
