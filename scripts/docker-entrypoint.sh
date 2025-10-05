#!/usr/bin/env bash
set -euo pipefail

# 1) Kafka Connect 기동
echo "[entrypoint] Starting Kafka Connect..."
/etc/confluent/docker/run &   # 백그라운드
CONNECT_PID=$!

echo "[entrypoint] Kafka Connect process launched in background with PID: $CONNECT_PID."
echo "[entrypoint] Pausing for 5 seconds to check if the process stays alive..."
sleep 5

if kill -0 $CONNECT_PID > /dev/null 2>&1; then
    echo "[entrypoint] CHECK SUCCESS: The Kafka Connect process (PID $CONNECT_PID) is running."
else
    echo "[entrypoint] CHECK FAILED: The Kafka Connect process (PID $CONNECT_PID) appears to have died."
fi

# 2) 커넥터 등록
echo "[entrypoint] Registering connectors..."
/scripts/register-connector.sh || { echo "[entrypoint] registration failed"; kill $CONNECT_PID; exit 1; }

# 3) Connect 프로세스 대기
wait $CONNECT_PID