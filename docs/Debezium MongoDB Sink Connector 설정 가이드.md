# MongoDB Sink Connector 설정 가이드

이 파일은 Kafka Connect에 등록할 **MongoDB Sink 커넥터**의 설정입니다.

팀원들은 IaC 방식으로 이 JSON을 Git으로 관리하며, 수정 후 배포하면 커넥터 설정이 자동 반영됩니다.


## 주요 필드 설명

```json
{
  "name": "mongo-sink",
  "config": {
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "topics": "mysql-events.inventory.member_mcp",

    "connection.uri": "${MONGO_CONNECTION_URI}",
    "database": "${MONGODB_DATABASE}",
    "collection": "member_mcp",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter.schemas.enable": "true",

    "document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.PartialValueStrategy",
    "document.id.strategy.partial.value.projection.list": "id",
    "document.id.strategy.partial.value.projection.type": "AllowList",

    "delete.on.null.values": "true"
  }
}

```


### 기본 정보

- `"name"`
    - 커넥터 이름 (Kafka Connect REST API에서 식별자 역할)
    - **주의**: 같은 Connect 클러스터 안에서는 고유해야 함.
- `"connector.class"`
    - MongoDB Sink 커넥터 클래스
    - 반드시 `"com.mongodb.kafka.connect.MongoSinkConnector"`
- `"topics"`
    - 소비할 Kafka 토픽 이름
    - MySQL Source Connector가 발행하는 CDC 이벤트 토픽과 동일해야 함
    - 예: `mysql-events.inventory.member_mcp`
- `"connection.uri"`
    - 연결할 **MongoDB 클러스터**의 URI.
- `"database"`
    - 데이터를 저장할 **MongoDB 데이터베이스** 이름.
- `"collection"`
    - 데이터를 저장할 **MongoDB 컬렉션** 이름.

### MongoDB 연결

- `"connection.uri"`
    - MongoDB 접속 URI
    - `.env` 의 `${MONGO_CONNECTION_URI}` 값을 사용 (유저/비번/호스트 포함)
    - 예: `mongodb://my_mongo_user:my_mongo_password@mongo:27017`
- `"database"` / `"collection"`
    - Sink할 MongoDB DB 이름과 Collection 이름
    - 여기서는 `.env` 기반 (`${MONGODB_DATABASE}`)


### 직렬화/포맷

- `"key.converter"`, `"value.converter"`
    - Kafka 메시지를 MongoDB에 저장할 때의 직렬화 방식
    - 현재는 JSON 기반 설정 (실험/개발용으로 적합)
    - 운영에서는 Avro/Schema Registry 조합도 가능

### Debezium CDC 이벤트 처리 전략

- `"change.data.capture.handler"`
    - **CDC 이벤트를 처리하는 방식**을 정의합니다. `ReplaceOneBusinessKeyHandler`는 Debezium의 `create`, `update`, `delete` 이벤트를 처리하는 핸들러입니다.
    - **동작 방식**: 메시지의 비즈니스 키(Business Key)를 사용하여 MongoDB 문서를 찾고, 변경 사항을 반영합니다. 새로운 레코드는 삽입하고, 기존 레코드는 대체하며, 삭제 이벤트는 문서를 제거합니다.
- `"document.id.strategy"`
    - MongoDB 문서의 `_id` 필드를 생성하는 전략을 지정합니다.
    - `PartialValueStrategy`는 메시지 페이로드의 특정 필드를 사용하여 `_id`를 만듭니다. 이 전략을 사용하면 MySQL의 **기본 키(Primary Key)**를 MongoDB의 **고유 식별자**로 그대로 사용할 수 있습니다.
- `"document.id.strategy.partial.value.projection.list"`
    - 문서 `_id`로 사용할 원본 메시지의 필드 이름을 지정합니다. 여기서는 MySQL 테이블의 `id` 컬럼이 사용됩니다.
    - 이 설정 덕분에 MySQL의 `id`가 MongoDB 문서의 `_id`로 매핑되어, 변경사항이 항상 올바른 문서를 업데이트하도록 보장합니다.
- `"delete.on.null.values"`
    - Debezium의 삭제 이벤트는 `value`가 `null`인 메시지로 표현됩니다. 이 설정을 `true`로 지정하면, 싱크 커넥터가 `null` 값 메시지를 받았을 때 해당 문서를 MongoDB에서 삭제합니다.

---

### 메시지 변환

- `"key.converter"`, `"value.converter"`
    - 카프카 메시지 키와 값을 읽어올 직렬화 방식입니다. Debezium 소스 커넥터와 동일하게 `JsonConverter`를 사용합니다.
- `"value.converter.schemas.enable"`, `"key.converter.schemas.enable"`
    - 메시지 페이로드에 스키마 정보가 포함되어 있는지 여부를 지정합니다. Debezium이 스키마를 포함하여 메시지를 보내므로 `true`로 설정해야 합니다.

### 삭제 처리

- `"delete.on.null.values": "true"`
    - Debezium 이벤트에서 `payload.after = null` 인 경우 → MongoDB에서 문서 삭제 처리

---

## 실무에서 자주 바꾸는 항목

1. **연결 정보**
    - `connection.uri` → 운영 MongoDB 클러스터 URI로 교체
    - 예: Atlas URI (`mongodb+srv://...`)
2. **Sink 대상**
    - `database`, `collection` → 신규 서비스별 MongoDB DB/Collection명 변경
3. **CDC 핸들링 전략**
    - `_id` 매핑 방식 (PK 외 다른 필드를 쓰고 싶을 때 `projection.list` 수정)
    - 삭제 동작 비활성화(`delete.on.null.values = false`) 가능
4. **토픽**
    - MySQL CDC 소스에서 새로운 테이블을 추가하면, 해당 토픽을 `topics` 에 등록

---