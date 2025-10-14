#!/usr/bin/env bash
# This script now only starts the Kafka Connect process.
# Connector registration is handled by the Strimzi operator in Kubernetes.

echo "Starting Kafka Connect..."
/etc/confluent/docker/run
