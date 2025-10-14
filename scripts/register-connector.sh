##!/usr/bin/env bash
#sleep 10
#set -euo pipefail
#
## 0) 환경
#CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"   # env 로 덮어쓰기 가능
#
#echo "[register] Using CONNECT_URL=$CONNECT_URL"
#
#register_connector() {
#  local CONFIG_FILE="$1"
#
#  # 1) 커넥터 이름 추출 (initContainer가 이미 치환한 파일 기준)
#  local CONNECTOR_NAME
#  CONNECTOR_NAME="$(jq -r '.name' "$CONFIG_FILE")"
#  if [ -z "$CONNECTOR_NAME" ] || [ "$CONNECTOR_NAME" = "null" ]; then
#    echo "[ERROR] .name is missing in $CONFIG_FILE"
#    exit 1
#  fi
#  echo "[register] Found connector config for: $CONNECTOR_NAME"
#
#  # 2) REST API Ready 대기 (최초 한번만 실행되도록 개선)
#  # 이 함수가 처음 호출될 때만 API 상태를 체크합니다.
#  if [ -z "$API_READY" ]; then
#    while true; do
#      RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$CONNECT_URL/")
#      HTTP_BODY=$(echo "$RESPONSE" | sed -e 's/HTTP_STATUS:.*//g')
#      HTTP_CODE=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
#      if [ "$HTTP_CODE" = "200" ]; then
#        echo "[register] Kafka Connect REST API ready."
#        API_READY="true" # API 상태 플래그 설정
#        break
#      fi
#      echo "[register] Waiting for Kafka Connect REST API (Status: $HTTP_CODE)..."
#      sleep 3
#    done
#  fi
#
#  # 3) 커넥터 생성/업데이트
#  for i in {1..3}
#  do
#    echo "[register] Attempting to register connector '$CONNECTOR_NAME' ($i/3)..."
#    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL/connectors/$CONNECTOR_NAME")
#
#    if [ "$STATUS" = "200" ]; then
#      echo "[register] Connector '$CONNECTOR_NAME' exists. Updating configuration (PUT)..."
#      RESPONSE=$(jq '.config' "$CONFIG_FILE" | curl -s -w "\n%{http_code}" -X PUT -H "Content-Type: application/json" \
#        --data @- \
#        "$CONNECT_URL/connectors/$CONNECTOR_NAME/config")
#      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
#
#      if [[ "$HTTP_CODE" =~ ^2 ]]; then
#        echo "[register] Connector '$CONNECTOR_NAME' updated successfully."
#        break
#      else
#        echo "[WARN] ($i/3) Failed to update connector. Kafka Connect returned status $HTTP_CODE."
#      fi
#    else
#      echo "[register] Connector '$CONNECTOR_NAME' not found. Creating (POST)..."
#      RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
#        --data @"$CONFIG_FILE" \
#        "$CONNECT_URL/connectors")
#      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
#
#      if [[ "$HTTP_CODE" =~ ^2 ]]; then
#        echo "[register] Connector '$CONNECTOR_NAME' created successfully."
#        break
#      else
#        echo "[WARN] ($i/3) Failed to create connector. Kafka Connect returned status $HTTP_CODE."
#      fi
#    fi
#
#    if [ "$i" -lt 3 ]; then
#      echo "[register] Retrying in 10 seconds..."
#      sleep 10
#    else
#      echo "[ERROR] Failed to register connector '$CONNECTOR_NAME' after 3 attempts."
#      exit 1
#    fi
#  done
#}
#
## /etc/kafka-connect 디렉터리의 모든 .json 파일을 찾아 커넥터 등록
#CONFIG_DIR="/etc/kafka-connect"
#if [ -d "$CONFIG_DIR" ] && [ "$(ls -A $CONFIG_DIR/*.json 2>/dev/null)" ]; then
#  for config_file in "$CONFIG_DIR"/*.json; do
#    register_connector "$config_file"
#  done
#else
#  echo "[WARN] No .json config files found in $CONFIG_DIR. No connectors will be registered."
#fi
#
#echo "[register] All connector registration tasks finished."
#
