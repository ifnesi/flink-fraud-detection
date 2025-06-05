#!/bin/bash

JSON_FILE="tf_aws_data.json"
TEMPLATE_FILE="./config/template.ini"
OUTPUT_FILE="./config/tf_config.ini"

IFS= # unset IFS to preserve line breaks
read -r -d '' OUTPUT < "$TEMPLATE_FILE"

placeholders=(
    "cc_kafka_cluster_bootstrap"
    "clients_kafka_cluster_key"
    "clients_kafka_cluster_secret"
    "cc_sr_cluster_endpoint"
    "sr_cluster_key"
    "sr_cluster_secret"
)

for item in "${placeholders[@]}"; do
    placeholder="\$$item"
    value=$(jq -r ."$item"."value" "$JSON_FILE")
    if [[ $item == "cc_kafka_cluster_bootstrap" ]]; then
        value=$(echo "$value" | cut -d'/' -f3)
    fi
    OUTPUT=${OUTPUT//$placeholder/$value}
done

echo $OUTPUT > "$OUTPUT_FILE"
