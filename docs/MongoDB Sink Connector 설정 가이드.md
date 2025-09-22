# MongoDB Sink Connector 설정 가이드

이 파일은 Kafka Connect에 등록할 **MongoDB Sink 커넥터**의 설정입니다.

팀원들은 IaC 방식으로 이 JSON을 Git으로 관리하며, 수정 후 배포하면 커넥터 설정이 자동 반영됩니다.

---

## 주요 설정 예시

```json
{
  "name": "mongo-sink",
  "config": {
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "topics": "mysql-events.inventory.member_mcp, mysql-events.inventory.mcp",
    "connection.uri": "mongodb://my_mongo_user:my_mongo_password@mongo:27017/my_mongo_db?authSource=admin",
    "database": "my_mongo_db",
    "collection": "member_mcp, mcp",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true",
    "key.converter.schemas.enable": "true",

    "document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.PartialValueStrategy",
    "document.id.strategy.partial.value.projection.list": "id",
    "document.id.strategy.partial.value.projection.type": "AllowList",

    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "true",
    "transforms.unwrap.delete.handling.mode": "rewrite",

    "value.projection.type": "BlockList",
    "value.projection.list": "mcp_token"
  }
}

```

---

## 기본 정보

- `"name"`
  - 커넥터 이름 (Kafka Connect REST API에서 식별자 역할)
  - **주의**: Connect 클러스터 내에서 고유해야 함
- `"connector.class"`
  - 반드시 `"com.mongodb.kafka.connect.MongoSinkConnector"`
- `"topics"`
  - 소비할 Kafka 토픽 이름 (여러 개 지정 가능, 콤마 구분)
  - 예: `mysql-events.inventory.member_mcp, mysql-events.inventory.mcp`
- `"connection.uri"`
  - MongoDB 접속 URI (유저/비밀번호/호스트/DB/인증 포함)
- `"database"` / `"collection"`
  - Sink할 MongoDB DB/Collection 지정
  - 여러 토픽에 대응하는 경우, collection도 쉼표로 구분하여 매핑

---

## 직렬화/포맷

- `"key.converter"`, `"value.converter"`
  - Kafka 메시지를 MongoDB에 저장할 때 직렬화 방식
  - 현재는 JSON 기반 설정
- `"key.converter.schemas.enable"`, `"value.converter.schemas.enable"`
  - Debezium은 스키마 정보를 포함하므로 `true` 유지

---

## MongoDB 문서 ID 전략

- `"document.id.strategy"`
  - MongoDB `_id` 필드 생성 전략
  - `PartialValueStrategy`: Kafka 메시지의 특정 필드를 `_id`로 사용
- `"document.id.strategy.partial.value.projection.list": "id"`
  - `_id`로 사용할 필드 지정 (예: MySQL PK `id`)
- `"document.id.strategy.partial.value.projection.type": "AllowList"`
  - 지정된 필드만 `_id` 생성에 사용

👉 MySQL의 PK를 MongoDB `_id`로 매핑 → update/delete 이벤트가 올바르게 반영됨

---

## Debezium 이벤트 처리 (unwrap SMT)

- `"transforms": "unwrap"`
  - Debezium 이벤트에서 **실제 데이터만 추출**
- `"transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState"`
  - `payload.after` 중심으로 메시지 구조 단순화
- `"transforms.unwrap.drop.tombstones": "true"`
  - Tombstone 이벤트(Kafka compact log용 null 메시지)는 무시
- `"transforms.unwrap.delete.handling.mode": "rewrite"`
  - 삭제 이벤트를 **null 메시지로 변환**하여 MongoDB Sink가 문서를 삭제할 수 있게 함

👉 따라서 MySQL → Kafka → MongoDB에서

- `INSERT`, `UPDATE` → MongoDB에 반영
- `DELETE` → MongoDB에서 해당 문서 삭제

---

## 필드 프로젝션

- `"value.projection.type": "BlockList"`
  - 특정 필드를 제외하고 MongoDB에 저장
- `"value.projection.list": "mcp_token"`
  - `mcp_token` 필드는 MongoDB에 저장하지 않음

---

## 실무에서 자주 바꾸는 항목

1. **연결 정보**
  - `connection.uri`, `database`, `collection` → 운영 MongoDB 클러스터/DB/컬렉션 이름으로 변경
2. **토픽 & 컬렉션 매핑**
  - 신규 테이블 추가 시 `topics` + `collection` 동시 수정 필요
  - 토픽 순서와 collection 순서가 매핑됨
3. **삭제 처리**
  - 이미 `rewrite` 모드로 설정되어 있으므로, 삭제 이벤트는 MongoDB에서도 반영됨
  - 삭제 반영을 원치 않을 경우 `"drop"`으로 되돌릴 수 있음
4. **필드 프로젝션**
  - 민감 정보(`mcp_token` 등)를 저장하지 않도록 BlockList 관리

---

👉 이 설정은 **MySQL CDC 이벤트(insert/update/delete)** 를 **MongoDB에 그대로 반영**하는 구성입니다.

토픽-컬렉션 매핑만 관리 잘 하면 안정적으로 운영할 수 있습니다.