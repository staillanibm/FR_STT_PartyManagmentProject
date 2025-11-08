export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_PROJECT_NAME=cdf-party

export COMPOSE_FILE=./docker-compose.yml
export COMPOSE_FILE=$COMPOSE_FILE:./squid/docker-compose.yaml
export COMPOSE_FILE=$COMPOSE_FILE:./edge-dev/docker-compose.yaml
export COMPOSE_FILE=$COMPOSE_FILE:./edge-test/docker-compose.yaml
export COMPOSE_FILE=$COMPOSE_FILE:./postgres/docker-compose.yaml
export COMPOSE_FILE=$COMPOSE_FILE:./kafka/docker-compose.yaml