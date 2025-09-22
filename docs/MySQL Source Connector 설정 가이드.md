# MySQL Source Connector 설정 가이드

이 파일은 Kafka Connect에 등록할 **MySQL Source Connector (Debezium 기반)** 설정입니다.

팀원들은 IaC 방식으로 이 JSON을 Git으로 관리하며, 수정 후 배포하면 커넥터 설정이 자동 반영됩니다.

---

## 주요 설정 예시

```json
{
  "name": "my-mysql-cdc-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",

    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "my_db_user",
    "database.password": "my_db_password",

    "database.server.id": "184054",
    "database.server.name": "mysql-cdc",

    "database.include.list": "inventory",
    "table.include.list": "inventory.member_mcp,inventory.mcp",

    "topic.prefix": "mysql-events",

    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-history-db-events",

    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "true",
    "transforms.unwrap.delete.handling.mode": "rewrite",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true"
  }
}

```

---

## 기본 정보

- `"name"`
    - 커넥터 이름 (Kafka Connect REST API에서 식별자 역할)
    - **주의**: Connect 클러스터 내에서 고유해야 함
- `"connector.class"`
    - 반드시 `"io.debezium.connector.mysql.MySqlConnector"`
    - Debezium MySQL CDC 커넥터 클래스
- `"tasks.max"`
    - 실행할 태스크 개수
    - 보통 1 (MySQL binlog 읽기는 단일 스트림이므로 병렬화 불가)

---

## MySQL 연결 정보

- `"database.hostname"`, `"database.port"`
    - MySQL 접속 정보
    - 예: `mysql:3306`
- `"database.user"`, `"database.password"`
    - MySQL CDC 계정 정보
    - **필수 권한**:
        - `REPLICATION SLAVE`
        - `REPLICATION CLIENT`
        - `SELECT`

---

## 서버 식별자

- `"database.server.id"`
    - MySQL replication 클라이언트 ID (고유해야 함)
    - 여러 커넥터가 같은 MySQL에 붙을 경우 충돌 방지를 위해 다른 값 사용
- `"database.server.name"`
    - Debezium이 Kafka에 이벤트를 보낼 때 토픽 prefix로 사용됨
    - 예: `mysql-cdc.inventory.member_mcp`

---

## 테이블/DB 필터링

- `"database.include.list"`
    - CDC 대상 DB (예: `inventory`)
- `"table.include.list"`
    - 특정 테이블만 CDC 대상으로 지정
    - 예: `inventory.member_mcp`, `inventory.mcp`
- `"topic.prefix"`
    - 최종 Kafka 토픽 prefix
    - 실제 토픽 이름은 `${topic.prefix}.${db}.${table}` 형식
    - 예: `mysql-events.inventory.member_mcp`

---

## 스키마 히스토리

- `"schema.history.internal.kafka.bootstrap.servers"`
    - Debezium이 DDL 변경 사항을 저장할 Kafka 클러스터
- `"schema.history.internal.kafka.topic"`
    - 스키마 변경 기록을 저장할 전용 토픽
    - 예: `schema-history-db-events`

---

## 메시지 변환 (unwrap SMT)

- `"transforms": "unwrap"`
    - Debezium 이벤트 구조를 간소화
- `"transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState"`
    - Kafka 메시지에서 `payload.after`만 추출
- `"transforms.unwrap.drop.tombstones": "true"`
    - Tombstone 메시지(카프카 compacted log용) 무시
- `"transforms.unwrap.delete.handling.mode": "rewrite"`
    - 삭제 이벤트를 **null 메시지**로 변환 → Sink 커넥터가 문서 삭제 처리 가능

👉 따라서 MySQL에서 발생한 **INSERT, UPDATE, DELETE** 이벤트가 모두 Kafka 토픽에 반영됨

---

## 직렬화/포맷

- `"key.converter"`, `"value.converter"`
    - Kafka 메시지 직렬화 방식
    - 현재 JSON 기반
- `"key.converter.schemas.enable"`, `"value.converter.schemas.enable"`
    - Debezium은 스키마를 포함하므로 `true`

---

## 실무에서 자주 바꾸는 항목

1. **MySQL 연결 정보**
    - `database.hostname`, `database.user`, `database.password` 운영 DB로 교체
2. **DB/테이블 대상**
    - 신규 DB/테이블 추가 시 `database.include.list`, `table.include.list` 수정
3. **토픽 네이밍**
    - `topic.prefix` → 팀 규칙에 맞는 네이밍으로 변경
4. **삭제 이벤트 처리**
    - 현재 `"rewrite"` → 삭제 이벤트도 Kafka에 반영됨
    - 삭제를 무시하고 싶으면 `"drop"`으로 되돌리면 됨
5. **schema.history 토픽**
    - 운영 Kafka 클러스터에 맞게 전용 토픽 이름 지정

---

👉 이 설정은 **MySQL → Kafka** CDC 파이프라인에서

`INSERT`, `UPDATE`, `DELETE` 이벤트를 모두 Kafka 토픽에 반영하도록 구성되어 있습니다.

MongoDB Sink와 연동하면 MySQL → MongoDB 데이터 동기화(삭제 포함)가 가능합니다.