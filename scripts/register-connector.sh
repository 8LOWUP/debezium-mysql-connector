#!/usr/bin/env bash
sleep 30
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

  # 파일 내 ${VAR_NAME} 패턴 추출
  vars=$(grep -o '\${[A-Z0-9_]\+}' "$CONFIG_FILE" | sed 's/\${\(.*\)}/$\1/g' | tr '\n' ' ' || true)

  # envsubst 안전 처리
  if [ -n "$vars" ]; then
    echo "[register] envsubst 치환 변수: $vars"
    envsubst "$vars" < "$CONFIG_FILE" > "$TMP_FILE"
  else
    echo "[register] 치환할 변수가 없습니다. 원본 파일을 그대로 사용합니다."
    cp "$CONFIG_FILE" "$TMP_FILE"
  fi

  # 3) 미치환 변수(예: ${FOO})가 남았는지 검사 (실수 방지)
  if grep -q '\${[^}]\+}' "$TMP_FILE"; then
    echo "[ERROR] Unresolved variables found in $TMP_FILE"
    grep -n '\${[^}]\+}' "$TMP_FILE" || true
    exit 1
  fi

  echo "=== [register] Resolved config ==="
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
    sleep 3
  done

  # 6) 커넥터 생성/업데이트 (최대 3번 시도)
  for i in {1..3}
  do
    echo "[register] 커넥터 '$CONNECTOR_NAME' 등록 시도 ($i/3)..."

    # 6-1) 커넥터 존재 여부 확인
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL/connectors/$CONNECTOR_NAME")

    if [ "$STATUS" = "200" ]; then
      # 6-2a) 존재하면 업데이트
      echo "[register] 커넥터 '$CONNECTOR_NAME'가 존재합니다. 설정을 업데이트합니다 (PUT)..."
      RESPONSE=$(jq '.config' "$TMP_FILE" | curl -s -w "\n%{http_code}" -X PUT -H "Content-Type: application/json" \
        --data @- \
        "$CONNECT_URL/connectors/$CONNECTOR_NAME/config")
      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
      HTTP_BODY=$(echo "$RESPONSE" | sed '$d')

      if [[ "$HTTP_CODE" =~ ^2 ]]; then
        echo "[register] 커넥터 설정이 성공적으로 업데이트되었습니다."
        echo "$HTTP_BODY" | jq '.' || true
        break  # 성공 시 루프 종료
      else
        echo "[WARN] ($i/3) 커넥터 업데이트 실패. 상태 코드: $HTTP_CODE"
        echo "[WARN] 응답: $HTTP_BODY"
      fi
    else
      # 6-2b) 없으면 생성
      echo "[register] 커넥터 '$CONNECTOR_NAME'를 생성합니다 (POST)..."
      RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
        --data @"$TMP_FILE" \
        "$CONNECT_URL/connectors")
      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
      HTTP_BODY=$(echo "$RESPONSE" | sed '$d')

      if [[ "$HTTP_CODE" =~ ^2 ]]; then
        echo "[register] 커넥터가 성공적으로 생성되었습니다."
        echo "$HTTP_BODY" | jq '.' || true
        break  # 성공 시 루프 종료
      else
        echo "[WARN] ($i/3) 커넥터 생성 실패. 상태 코드: $HTTP_CODE"
        echo "[WARN] 응답: $HTTP_BODY"
      fi
    fi

    if [ "$i" -lt 3 ]; then
      echo "[register] 30초 후 재시도합니다..."
      sleep 30
    else
      echo "[ERROR] 3번의 시도 후에도 커넥터 '$CONNECTOR_NAME' 등록에 실패했습니다."
      exit 1
    fi
  done
}

# 여러 커넥터 등록
register_connector /etc/kafka-connect/connector-mcp-config.json
register_connector /etc/kafka-connect/connector-member-config.json
register_connector /etc/kafka-connect/connector-mcp-mcp_url-config.json
register_connector /etc/kafka-connect/mongo-sink-config.json
register_connector /etc/kafka-connect/redis-sink-config.json
register_connector /etc/kafka-connect/elasticsearch-sink-config.json
register_connector /etc/kafka-connect/mongo-sink-mcpUrl-config.json
register_connector /etc/kafka-connect/elasticsearch-sink-embedding-config.json