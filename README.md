


## IaC 워크플로우

1. **MySQL에 새로운 테이블 추가**: `inventory.new_table`을 추가했다고 가정합니다.
2. **소스 커넥터 설정 수정**: `debezium-mysql-source.json` 파일을 열어 `table.include.list`에 새로운 테이블명을 추가합니다.
    - `"table.include.list": "inventory.member_mcp,inventory.mcp,inventory.new_table"`
3. **싱크 커넥터 설정 수정**: `mongo-sink.json` 파일을 열어 `topics`와 `topic.to.collection.map` (사용하는 경우)을 수정합니다.
    - `"topics": "mysql-events.inventory.member_mcp,mysql-events.inventory.mcp,mysql-events.inventory.new_table"`
    - `"topic.to.collection.map": "{\"...\":\"...\", \"mysql-events.inventory.new_table\":\"new_table\"}"`
4. **Git으로 관리**: 수정된 JSON 파일들을 커밋하고 푸시합니다.