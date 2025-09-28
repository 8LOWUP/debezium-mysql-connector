-- mm 유저가 mm_local DB에 접근할 수 있도록 권한 부여
GRANT ALL PRIVILEGES ON mm_local.* TO 'mm'@'%';

-- Debezium을 위한 권한 추가
GRANT REPLICATION SLAVE, REPLICATION CLIENT, RELOAD, SHOW DATABASES, SUPER, FLUSH_TABLES ON *.* TO 'mm'@'%';

FLUSH PRIVILEGES;