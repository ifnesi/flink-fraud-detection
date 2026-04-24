#!/usr/bin/env bash
set -euo pipefail

wait_for_broker() {
  local host="$1"
  local port="$2"
  echo "Waiting for broker at ${host}:${port} ..."
  while ! (echo > "/dev/tcp/${host}/${port}") 2>/dev/null; do
    echo "  ${host}:${port} not ready yet, sleeping 2s..."
    sleep 2
  done
  echo "Broker ${host}:${port} is up."
}

wait_for_http() {
  local url="$1"
  echo "Waiting for HTTP ${url} ..."
  until curl -sSf "${url}" >/dev/null 2>&1; do
    echo "  ${url} not ready yet, sleeping 2s..."
    sleep 2
  done
  echo "HTTP ${url} is up."
}

# Wait for broker inside the Docker network
wait_for_broker broker 29092

echo "Creating topics (idempotent)..."
kafka-topics --bootstrap-server broker:29092 \
    --create --if-not-exists \
    --topic card-transactions \
    --partitions 1 \
    --replication-factor 1
kafka-topics --bootstrap-server broker:29092 \
    --create --if-not-exists \
    --topic users-config \
    --config cleanup.policy=compact \
    --partitions 1 \
    --replication-factor 1
kafka-topics --bootstrap-server broker:29092 \
    --create --if-not-exists \
    --topic card-transactions-enriched \
    --partitions 1 \
    --replication-factor 1

# Wait Schema Registry inside the Docker network
wait_for_http http://schema-registry:8081/subjects

# Flatten schemas to one line and escape quotes for JSON
CARD_SCHEMA=$(tr -d '\n' < /schemas/card_transactions.avro | sed 's/"/\\"/g')
USERS_SCHEMA=$(tr -d '\n' < /schemas/users_config.avro     | sed 's/"/\\"/g')

echo "Registering card-transactions-value schema..."
echo "{\"schema\":\"${CARD_SCHEMA}\"}" | curl -sS -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @- \
  http://schema-registry:8081/subjects/card-transactions-value/versions
echo

echo "Registering users-config-value schema..."
echo "{\"schema\":\"${USERS_SCHEMA}\"}" | curl -sS -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @- \
  http://schema-registry:8081/subjects/users-config-value/versions
echo

echo "Topic + schema init completed. Bye bye!"
