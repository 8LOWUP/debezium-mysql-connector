#!/usr/bin/env bash
set -euo pipefail

# 1) Kafka Connect 기동
echo "[entrypoint] Starting Kafka Connect..."
/etc/confluent/docker/run &   # 백그라운드
CONNECT_PID=$!

# 2) 커넥터 등록
echo "[entrypoint] Registering connectors..."
/scripts/register-connector.sh || { echo "[entrypoint] registration failed"; kill $CONNECT_PID; exit 1; }

# 3) Connect 프로세스 대기
wait $CONNECT_PID