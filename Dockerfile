# Confluent Kafka Connect 기본 이미지 사용
FROM confluentinc/cp-kafka-connect:7.4.0

USER root

# 스크립트
COPY scripts/register-connector.sh /scripts/register-connector.sh
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /scripts/register-connector.sh /docker-entrypoint.sh



# 유틸
RUN yum install -y curl jq gettext unzip && yum clean all

# --- Confluent Hub 및 직접 다운로드를 통해 플러그인 설치 ---
RUN set -eux; \
    echo "Installing connectors..."; \
    # Elasticsearch connector from Confluent Hub
    confluent-hub install confluentinc/kafka-connect-elasticsearch:15.0.1 --no-prompt; \
    # Redis connector from GitHub releases
    curl -fSL --retry 5 "https://github.com/redis-field-engineering/redis-kafka-connect/releases/download/v0.9.1/redis-redis-kafka-connect-0.9.1.zip" -o /tmp/redis.zip; \
    unzip -q /tmp/redis.zip -d /opt/kafka-plugins/; \
    rm -f /tmp/redis.zip


# --- 기존 플러그인 설치 ---
# Debezium MySQL (2.7.0.Final)
RUN set -eux; \
    curl -fSL --retry 5 --retry-connrefused --retry-delay 2 \
      https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.7.0.Final/debezium-connector-mysql-2.7.0.Final-plugin.tar.gz \
      -o /tmp/debezium-mysql.tar.gz; \
    tar -xf /tmp/debezium-mysql.tar.gz -C /opt/kafka-plugins; \
    rm -f /tmp/debezium-mysql.tar.gz

# MongoDB Kafka Connector (1.15.0 uber JAR)
RUN set -eux; \
    mkdir -p /opt/kafka-plugins/mongo-connector; \
    curl -fSL --retry 5 --retry-connrefused --retry-delay 2 \
      https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.15.0/mongo-kafka-connect-1.15.0-all.jar \
      -o /opt/kafka-plugins/mongo-connector/mongo-kafka-connect-1.15.0-all.jar; \
    test -s /opt/kafka-plugins/mongo-connector/mongo-kafka-connect-1.15.0-all.jar


USER appuser
ENTRYPOINT ["/docker-entrypoint.sh"]
