# Debezium MySQL Connector 설정 가이드

이 파일은 Kafka Connect에 등록할 **MySQL CDC(변경 데이터 캡처) 커넥터**의 설정입니다.

팀원들은 IaC 방식으로 이 JSON을 Git으로 관리하며, 수정 후 배포하면 커넥터 설정이 자동 반영됩니다.

---

## 주요 필드 설명

```json
{
  "name": "my-mysql-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",

    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "${MYSQL_USER}",
    "database.password": "${MYSQL_PASSWORD}",

    "database.server.id": "184054",
    "database.server.name": "mysql-cdc",
    "topic.prefix": "mysql-mymcp-events",

    "database.include.list": "inventory",
    "table.include.list": "inventory.member_mcp,inventory.mcp",

    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-history-db-events",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true"
  }
}

```

---

### 1. 기본 정보

- `"name"`
    - 커넥터 이름 (Kafka Connect REST API에서 식별자 역할)
    - **주의**: 같은 Connect 클러스터 안에서는 고유해야 합니다.
- `"connector.class"`
    - 사용되는 Debezium 커넥터 종류
    - MySQL을 감시할 때는 반드시 `"io.debezium.connector.mysql.MySqlConnector"`
- `"tasks.max"`
    - 병렬 실행할 Task 개수 (테이블/파티션 수에 따라 늘리면 성능 ↑)

---

### 2. MySQL 연결

- `"database.hostname"` / `"database.port"`
    - CDC 대상 MySQL 서버 주소와 포트
    - 프로덕션에서는 RDS/CloudSQL 엔드포인트로 교체
- `"database.user"` / `"database.password"`
    - CDC용 계정 (REPLICATION CLIENT/SLAVE 권한 필요)
    - 여기서는 `.env` 값으로 치환됨 (`${MYSQL_USER}`, `${MYSQL_PASSWORD}`)

---

### 3. Kafka 이벤트 관련

- `"database.server.id"`
    - MySQL 클러스터 내에서 유니크해야 하는 ID
    - 보통 임의의 정수 (다른 커넥터와 중복되면 안 됨)
- `"database.server.name"`
    - 이 CDC 소스의 논리적 이름 → **Kafka 토픽 prefix**의 일부가 됨
    - 예: `"mysql-cdc"` → 토픽 이름은 `"mysql-mymcp-events.inventory.member_mcp"`
- `"topic.prefix"`
    - 모든 CDC 토픽의 접두사
    - 여러 MySQL 소스를 수집할 때 충돌 방지용

---

### 4. 감시 대상 범위

- `"database.include.list"`
    - 감시할 DB 이름 지정 (쉼표로 여러 개 가능)
    - 예: `"inventory,shop,orders"`
- `"table.include.list"`
    - 감시할 테이블 목록 (DB명.테이블명 형태, 쉼표로 구분)
    - **테이블 늘리고 싶다면?**
        - 단순히 여기에 새로운 테이블명을 추가하면 됨
        - 예:

            ```json
            "table.include.list": "inventory.member_mcp,inventory.mcp,inventory.mcp_user"
            
            ```


---

### 5. Schema History 저장

- `"schema.history.internal.kafka.bootstrap.servers"`
    - Schema history (DDL 이벤트 기록)를 저장할 Kafka 브로커 주소
- `"schema.history.internal.kafka.topic"`
    - DDL 이벤트 저장할 내부 토픽 이름
    - 운영환경에서는 replication factor 3 권장

---

### 6. 메시지 포맷

- `"key.converter"`, `"value.converter"`
    - Kafka에 발행될 메시지의 직렬화 방식
    - 지금은 JSON, 운영에서는 **Avro + Schema Registry**를 권장

---

## 실무에서 자주 바꾸는 항목

1. **MySQL 연결**
    - `database.hostname`, `database.user`, `database.password` → 클라우드 DB 환경에 맞게 변경
2. **감시 범위**
    - `database.include.list` / `table.include.list` → 감시 DB/테이블 추가/제거
3. **Kafka 연결**
    - `schema.history.internal.kafka.bootstrap.servers` → 프로덕션 Kafka endpoint로 교체
    - 필요 시 SASL/SSL 설정 추가

---

## 워크플로우 (IaC 관점)

1. Git에서 `connector-config.json` 수정 후 PR → Merge
2. CI/CD 파이프라인이 Connect 워커에 `PUT /connectors/my-mysql-cdc-connector/config` 실행 → 변경 반영
3. 변경 내역은 Git 이력으로 관리 (누가 언제 어떤 테이블을 추가했는지 추적 가능)