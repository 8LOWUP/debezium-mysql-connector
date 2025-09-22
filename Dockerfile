# Confluent Kafka Connect 기본 이미지 사용
FROM confluentinc/cp-kafka-connect:7.4.0

# root 권한 얻기
USER root

# 스크립트 복사 및 실행 권한 부여
COPY scripts/register-connector.sh /scripts/register-connector.sh
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /scripts/register-connector.sh /docker-entrypoint.sh

# 플러그인 설치 경로
ENV CONNECT_PLUGIN_PATH=/opt/kafka-plugins

# 플러그인 디렉토리 + 필요한 유틸 설치
RUN mkdir -p /opt/kafka-plugins && \
    yum install -y curl jq gettext && \
    \
    # Debezium MySQL 커넥터 설치 (.tar.gz)
    curl -L https://repo1.maven.org/maven2/io/debezium/debezium-connector-mysql/2.7.0.Final/debezium-connector-mysql-2.7.0.Final-plugin.tar.gz \
    -o /tmp/debezium-mysql.tar.gz && \
    tar -xvf /tmp/debezium-mysql.tar.gz -C /opt/kafka-plugins && \
    rm /tmp/debezium-mysql.tar.gz && \
    \
    # MongoDB Kafka Connector 설치 (1.15.0, uber JAR)
    curl -L https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.15.0/mongo-kafka-connect-1.15.0-all.jar \
        -o /opt/kafka-plugins/mongo-kafka-connect-1.15.0-all.jar


USER appuser

# 진입점 스크립트 설정
ENTRYPOINT ["/docker-entrypoint.sh"]
