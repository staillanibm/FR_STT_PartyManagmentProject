DOCKER_RUNTIME=docker
OCP_REGISTRY=default-route-openshift-image-registry.apps.68f62d11926501b4673f4b0b.am1.techzone.ibm.com
OCP_NAMESPACE ?= default
ERT_IMAGE_NAME=cdf-edge-runtime
ERT_IMAGE_TAG=11.2.3.0
PARTY_IMAGE_NAME=cdf-party-management
PARTY_IMAGE_TAG=1.0.3
KAFKA_POD ?= kafka-0
BOOTSTRAP_SERVER_PLAINTEXT ?= localhost:9093
TOPIC ?= test-topic

# ════════════════════════════════════════════════════════════════════════
# IMAGE MANAGEMENT
# ════════════════════════════════════════════════════════════════════════

docker-login-whi:
	@echo ${WHI_CR_PASSWORD} | $(DOCKER_RUNTIME) login ${WHI_CR_SERVER} -u ${WHI_CR_USERNAME} --password-stdin

docker-login-gh:
	@echo ${GH_CR_PASSWORD} | $(DOCKER_RUNTIME) login ${GH_CR_SERVER} -u ${GH_CR_USERNAME} --password-stdin

docker-login-ocp:
	@$(DOCKER_RUNTIME) login $(OCP_REGISTRY) -u kubeadmin -p $$(oc whoami -t) 

docker-build-dev:
	@$(DOCKER_RUNTIME) build -t $(ERT_IMAGE_NAME):$(ERT_IMAGE_TAG) --platform=linux/amd64 --build-arg WPM_TOKEN=${WPM_TOKEN} -f ./resources/build/Dockerfile_dev .

docker-build-test:
	@$(DOCKER_RUNTIME) build -t $(OCP_REGISTRY)/$(OCP_NAMESPACE)/$(PARTY_IMAGE_NAME):$(PARTY_IMAGE_TAG) --platform=linux/amd64 --build-arg WPM_TOKEN=${WPM_TOKEN} --build-arg GIT_TOKEN=${GIT_TOKEN} -f ./resources/build/Dockerfile_test .

docker-push-ocp:
	$(DOCKER_RUNTIME) push $(OCP_REGISTRY)/$(OCP_OCP_NAMESPACE)/$(PARTY_IMAGE_NAME):$(PARTY_IMAGE_TAG)

# ════════════════════════════════════════════════════════════════════════
# DOCKER COMPOSE DEPLOYMENT
# (modify ./resources/compose/setenv.sh to select the runtimes)
# ════════════════════════════════════════════════════════════════════════

docker-deploy:
	./resources/compose/up.sh

docker-undeploy:
	./resources/compose/down.sh

docker-undeploy:
	./resources/compose/status.sh

docker-logs-edge-dev:
	$(DOCKER_RUNTIME) logs -f edge-dev

docker-logs-edge-test:
	$(DOCKER_RUNTIME) logs -f edge-test

# ════════════════════════════════════════════════════════════════════════
# KAFKA ADMINISTRATION (DOCKER)
# ════════════════════════════════════════════════════════════════════════

docker-kafka-certs-gen:
	./resources/compose/kafka/generate-certs.sh

docker-kafka-broker-info:
	$(DOCKER_RUNTIME) exec -it kafka kafka-broker-api-versions \
  		--bootstrap-server localhost:9092 \
  		--command-config /etc/kafka/secrets/admin-client.properties

docker-kafka-list-topics:
	$(DOCKER_RUNTIME) exec -it kafka kafka-topics \
  		--list \
  		--bootstrap-server localhost:9092 \
  		--command-config /etc/kafka/secrets/admin-client.properties

docker-kafka-create-topic:
	$(DOCKER_RUNTIME) exec -it kafka kafka-topics \
  		--create \
  		--topic $(TOPIC) \
  		--bootstrap-server localhost:9092 \
  		--command-config /etc/kafka/secrets/admin-client.properties \
  		--partitions 1 \
  		--replication-factor 1

docker-kafka-produce:
	echo "Type your messages then press Ctrl+C to exit."
	$(DOCKER_RUNTIME) exec -it kafka kafka-console-producer \
  		--topic $(TOPIC) \
  		--bootstrap-server localhost:9092 \
  		--producer.config /etc/kafka/secrets/producer-client.properties

docker-kafka-consume:
	echo "Press Ctrl+C to exit."
	$(DOCKER_RUNTIME) exec kafka kafka-console-consumer \
  		--topic $(TOPIC) \
		--max-messages 100 \
  		--bootstrap-server localhost:9092 \
  		--consumer.config /etc/kafka/secrets/consumer-client.properties

docker-kafka-list-consumer-groups:
	$(DOCKER_RUNTIME) exec -it kafka kafka-consumer-groups \
  		--list \
  		--bootstrap-server localhost:9092 \
  		--command-config /etc/kafka/secrets/admin-client.properties

docker-kafka-describe-consumer-group:
	$(DOCKER_RUNTIME) exec -it kafka kafka-consumer-groups \
  		--describe \
  		--group $(GROUP) \
  		--bootstrap-server localhost:9092 \
  		--command-config /etc/kafka/secrets/admin-client.properties

# ════════════════════════════════════════════════════════════════════════
# OPENSHIFT DEPLOYMENT
# ════════════════════════════════════════════════════════════════════════

ocp-deploy-france:
	kubectl apply -k ./resources/openshift/overlays/france

ocp-deploy-latam:
	kubectl apply -k ./resources/openshift/overlays/latam

# ════════════════════════════════════════════════════════════════════════
# KAFKA ADMINISTRATION (OPENSHIFT)
# ════════════════════════════════════════════════════════════════════════

ocp-kafka-broker-info:
	@echo "Kafka broker info:"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-broker-api-versions \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-list-topics:
	@echo "Available topics:"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-topics \
		--list \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-create-topic:
	@echo "Creating topic: $(TOPIC)"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-topics \
		--create \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT) \
		--partitions $(PARTITIONS) \
		--replication-factor $(REPLICATION_FACTOR) \
		--if-not-exists

ocp-kafka-describe-topic:
	@echo "Describing topic: $(TOPIC)"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-topics \
		--describe \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-delete-topic:
	@echo "Deleting topic: $(TOPIC)"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-topics \
		--delete \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-produce:
	@echo "Producing to topic: $(TOPIC)"
	@echo "────────────────────────────────────────────────────────────"
	@echo "Type your messages then press Ctrl+C to exit."
	@echo ""
	oc exec -it $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-console-producer \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-consume:
	@echo "Consuming from topic: $(TOPIC)"
	@echo "────────────────────────────────────────────────────────────"
	@echo "Press Ctrl+C to exit."
	@echo ""
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-console-consumer \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT) \
		--from-beginning \
		--max-messages 100

ocp-kafka-consume-tail:
	@echo "Consuming from topic: $(TOPIC) (latest messages)"
	@echo "────────────────────────────────────────────────────────────"
	@echo "Press Ctrl+C to exit."
	@echo ""
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-console-consumer \
		--topic $(TOPIC) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-list-consumer-groups:
	@echo "Available consumer groups:"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-consumer-groups \
		--list \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-describe-consumer-group:
	@echo "Describing consumer group: $(GROUP)"
	@echo "────────────────────────────────────────────────────────────"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-consumer-groups \
		--describe \
		--group $(GROUP) \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)

ocp-kafka-reset-consumer-group-offset:
	@echo "Resetting consumer group offsets: $(GROUP)"
	@echo "────────────────────────────────────────────────────────────"
	@echo "Resetting to earliest (--to-earliest):"
	oc exec $(KAFKA_POD) -n $(OCP_NAMESPACE) -- \
		kafka-consumer-groups \
		--reset-offsets \
		--group $(GROUP) \
		--topic $(TOPIC) \
		--to-earliest \
		--execute \
		--bootstrap-server $(BOOTSTRAP_SERVER_PLAINTEXT)
