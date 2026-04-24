#!/usr/bin/env bash
set -euo pipefail

echo "Waiting for Flink JobManager at flink-jobmanager:9081 ..."
# Wait for the REST endpoint to respond
until curl -sf http://flink-jobmanager:9081/overview >/dev/null 2>&1; do
  echo "  JobManager not ready yet, sleeping 2s..."
  sleep 2
done
echo "JobManager is up, running bootstrap.sql"

# Run DDL + INSERT file
/opt/flink/bin/sql-client.sh -f /sql/bootstrap.sql