#!/bin/bash
CONNECTOR_CONFIG_FILE=$1
CONNECTOR_NAME=$(jq -r '.name' "$CONNECTOR_CONFIG_FILE")

CONNECT_URL="http://localhost:8083" # todo 배포용으로 수정 필요

# REST API 준비될 때까지 대기
while true; do
  HTTP_CODE=$(curl -s -o /dev/null -w %{http_code} $CONNECT_URL/)
  if [ "$HTTP_CODE" == "200" ]; then
    echo "Kafka Connect REST API ready. Registering connector '$CONNECTOR_NAME'..."
    break
  fi
  echo "Waiting for Kafka Connect REST API (Status: $HTTP_CODE)..."
  sleep 5
done

# 치환된 JSON을 임시 파일로 저장
TMP_FILE=/tmp/connector-config-resolved.json
envsubst < "$CONNECTOR_CONFIG_FILE" > $TMP_FILE

echo "=== Using resolved connector config ==="
cat $TMP_FILE

# 커넥터 등록
curl -X POST -H "Content-Type: application/json" \
     --data @"$TMP_FILE" \
     $CONNECT_URL/connectors

echo "Connector registration sent."
