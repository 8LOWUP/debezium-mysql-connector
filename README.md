# IaC 워크플로우

Kafka Connect 커넥터 설정은 Git으로 관리되며, 테이블 추가/변경 시 IaC 방식으로 JSON 파일을 수정하고 배포합니다.

---

## 워크플로우 단계

1. **MySQL에 새로운 테이블 추가**
   - 예: `inventory.new_table` 추가
2. **소스 커넥터 설정 수정** (`debezium-mysql-source.json`)
   - CDC 대상 테이블 목록에 새로운 테이블을 추가

    ```json
    "table.include.list": "inventory.member_mcp,inventory.mcp,inventory.new_table"
    
    ```

3. **싱크 커넥터 설정 수정** (`mongo-sink.json`)
   - `topics` 항목에 새로운 테이블의 CDC 토픽 추가
   - 필요 시 `topic.to.collection.map` 도 함께 수정 (토픽 ↔ 컬렉션 매핑)

    ```json
    "topics": "mysql-events.inventory.member_mcp,mysql-events.inventory.mcp,mysql-events.inventory.new_table",
    "topic.to.collection.map": "{\"mysql-events.inventory.member_mcp\":\"member_mcp\", \"mysql-events.inventory.mcp\":\"mcp\", \"mysql-events.inventory.new_table\":\"new_table\"}"
    
    ```

4. **Git으로 관리**
   - 수정된 JSON 파일들을 Git에 커밋 후 푸시
   - 배포 파이프라인(IaC 자동화)이 이를 감지하여 Kafka Connect 설정을 자동 반영

---

## CDC 역할

1. **✅MCP 도메인의 유저 소유 MCP 목록을 Workspace 에 동기화 (생성, 변경, 삭제)**
2. **✅MCP 도메인의 MCP URL을 Workspace 에 동기화 (생성, 변경, 삭제)**
3. **✅Member 도메인에서 멤버 생성 시, elasticsearch 에 저장되는 키워드 동기화 (변경, 삭제)**
4. **✅Member 도메인에서 멤버 정보 변경 시, redis 의 cache table 동기화 (변경, 삭제)**
5. **MCP 도메인에서 새로운 MCP 생성, 설명 또는 카테고리 변경, 삭제 시, (추천 알고리즘에 사용할) mongoDB에 벡터 데이터 동기화 (생성, 변경, 삭제)**

---

## 참고 문서
- [MySQL Source Connector 설정 가이드](./docs/MySQL%20Source%20Connector%20설정%20가이드.md)
- [MongoDB Sink Connector 설정 가이드](./docs/MongoDB%20Sink%20Connector%20설정%20가이드.md)

