#!/bin/bash

CONNECT_URL="http://localhost:8083" # todo 배포용으로 수정 필요, env로 받기

# 커넥터 등록 함수
register_connector() {
  CONFIG_FILE=$1 # 커넥터 설정 파일 경로
  CONNECTOR_NAME=$(jq -r '.name' "$CONFIG_FILE") # 커넥터 이름 추출

  echo "Registering connector '$CONNECTOR_NAME'..."

  TMP_FILE=/tmp/connector-config-resolved.json # 임시 파일 경로
  envsubst < "$CONFIG_FILE" > $TMP_FILE # 환경 변수 치환

  echo "=== Using resolved connector config for $CONNECTOR_NAME ==="
  cat $TMP_FILE

  # 커넥터 존재 여부 확인 후 등록
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" $CONNECT_URL/connectors/$CONNECTOR_NAME)
  if [ "$STATUS" == "200" ]; then
    echo "Connector '$CONNECTOR_NAME' already exists. Skipping..."
  else
    curl -s -X POST -H "Content-Type: application/json" \
      --data @"$TMP_FILE" \
      $CONNECT_URL/connectors
    echo "Connector '$CONNECTOR_NAME' registration sent."
  fi
}

# REST API 준비될 때까지 대기
while true; do
  HTTP_CODE=$(curl -s -o /dev/null -w %{http_code} $CONNECT_URL/)
  if [ "$HTTP_CODE" == "200" ]; then
    echo "Kafka Connect REST API ready."
    break
  fi
  echo "Waiting for Kafka Connect REST API (Status: $HTTP_CODE)..."
  sleep 5
done

# 여러 커넥터 등록
register_connector /etc/kafka-connect/connector-config.json
register_connector /etc/kafka-connect/mongo-sink-config.json