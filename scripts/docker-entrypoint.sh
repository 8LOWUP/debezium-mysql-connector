#!/bin/bash
set -e

# 1. Kafka Connect 프로세스 실행 (백그라운드)
echo "Starting Kafka Connect..."
/etc/confluent/docker/run &

# 2. Connect REST API 뜰 때까지 기다렸다가 등록 스크립트 실행
/scripts/register-connector.sh

# 3. Kafka Connect 프로세스가 종료될 때까지 대기
wait -n
