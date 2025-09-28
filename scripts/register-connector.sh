#!/usr/bin/env bash
set -euo pipefail

# 0) 환경
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"   # env 로 덮어쓰기 가능
ENV_PATH="${ENV_PATH:-/etc/local.env}"

# 1) .env 를 별도로 마운트했다면 로드 (compose에 env_file만 쓰면 불필요)
if [ -f "$ENV_PATH" ]; then
  echo "[register] Sourcing $ENV_PATH"
  set -a; . "$ENV_PATH"; set +a
fi

echo "[register] Using CONNECT_URL=$CONNECT_URL"

register_connector() {
  local CONFIG_FILE="$1"

  # 2) envsubst 로 치환
  local TMP_FILE="/tmp/$(basename "$CONFIG_FILE").resolved.json"
  echo "[register] Resolving env vars in $CONFIG_FILE -> $TMP_FILE"
  vars=$(grep -o '\${[A-Z_]*\}' "$CONFIG_FILE" | sed 's/\${\(.*\)}/$\1/g' | tr '\n' ' ')
  envsubst "$vars" < "$CONFIG_FILE" > "$TMP_FILE"

  # 3) 미치환 변수(예: ${FOO})가 남았는지 검사 (실수 방지)
  if grep -q '\${[^}]\+}' "$TMP_FILE"; then
    echo "[ERROR] Unresolved variables found in $TMP_FILE"
    grep -n '\${[^}]\+}' "$TMP_FILE" || true
    exit 1
  fi

  echo "=== [register] Resolved config ==="
  cat "$TMP_FILE" | sed 's/"/\\"/g' > /dev/null  # (보기용 echo 생략 가능)
  cat "$TMP_FILE"

  # 4) 커넥터 이름 추출 (치환된 파일 기준)
  local CONNECTOR_NAME
  CONNECTOR_NAME="$(jq -r '.name' "$TMP_FILE")"
  if [ -z "$CONNECTOR_NAME" ] || [ "$CONNECTOR_NAME" = "null" ]; then
    echo "[ERROR] .name is missing in $TMP_FILE"
    exit 1
  fi
  echo "[register] Connector name: $CONNECTOR_NAME"

  # 5) REST API Ready 대기
  while true; do
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$CONNECT_URL/")
    HTTP_BODY=$(echo "$RESPONSE" | sed -e 's/HTTP_STATUS:.*//g')
    HTTP_CODE=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
    if [ "$HTTP_CODE" = "200" ]; then
      echo "[register] Kafka Connect REST API ready."
      break
    fi
    echo "[register] Waiting for Kafka Connect REST API (Status: $HTTP_CODE)..."
    echo "  -> Status Code: $HTTP_CODE"
    echo "  -> Response Body:"
    echo "$HTTP_BODY"
    echo "  -> Raw curl output:"
    echo "$RESPONSE"
    sleep 3
  done

  # 6) 이미 존재하면 업데이트, 없으면 생성
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL/connectors/$CONNECTOR_NAME")
  if [ "$STATUS" = "200" ]; then
    echo "[register] Connector '$CONNECTOR_NAME' exists. Updating config via PUT..."
    RESPONSE=$(jq '.config' "$TMP_FILE" | curl -s -w "\n%{http_code}" -X PUT -H "Content-Type: application/json" \
      --data @- \
      "$CONNECT_URL/connectors/$CONNECTOR_NAME/config")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    HTTP_BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      echo "[register] Connector config updated successfully."
      echo "$HTTP_BODY" | jq '.' || true
    else
      echo "[ERROR] Failed to update connector. Kafka Connect returned status $HTTP_CODE."
      echo "[ERROR] Response: $HTTP_BODY"
      exit 1
    fi
    echo "[register] Update request sent."
  else
    echo "[register] Creating connector '$CONNECTOR_NAME' via POST..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
      --data @"$TMP_FILE" \
      "$CONNECT_URL/connectors")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    HTTP_BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" =~ ^2 ]]; then
      echo "[register] Connector created successfully."
      echo "$HTTP_BODY" | jq '.' || true
    else
      echo "[ERROR] Failed to create connector. Kafka Connect returned status $HTTP_CODE."
      echo "[ERROR] Response: $HTTP_BODY"
      exit 1
    fi
    echo "[register] Create request sent."
  fi
}

# 여러 커넥터 등록
register_connector /etc/kafka-connect/connector-mcp-config.json
register_connector /etc/kafka-connect/connector-member-config.json
register_connector /etc/kafka-connect/mongo-sink-config.json
register_connector /etc/kafka-connect/redis-sink-config.json
register_connector /etc/kafka-connect/elasticsearch-sink-config.json