# Руководство по нагрузочному тестированию стека (Часть 3)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

### 9.4. Нагрузочное тестирование баз данных

#### 9.4.1. Тестирование PostgreSQL

```bash
# Установка pgbench, если не установлен
apt-get install -y postgresql-client

# Создание скрипта для тестирования PostgreSQL
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-postgres-load.sh << 'EOF'
#!/bin/bash

echo "Подготовка к нагрузочному тестированию PostgreSQL..."

# Подготовка тестовой базы данных
docker exec postgres psql -U $POSTGRES_USER -c "DROP DATABASE IF EXISTS pgbench_test;"
docker exec postgres psql -U $POSTGRES_USER -c "CREATE DATABASE pgbench_test;"

# Инициализация pgbench
docker exec postgres pgbench -i -s 50 -U $POSTGRES_USER pgbench_test

# Запуск тестирования
echo "Запуск тестирования PostgreSQL..."
docker exec postgres pgbench -c 10 -j 2 -T 60 -U $POSTGRES_USER pgbench_test

# Тестирование с разным числом клиентов
for clients in 10 20 50; do
  echo "--- Тестирование с $clients клиентами ---"
  docker exec postgres pgbench -c $clients -j 2 -T 30 -U $POSTGRES_USER pgbench_test
  sleep 5
done

echo "Тестирование PostgreSQL завершено"
EOF

chmod +x /tmp/test-postgres-load.sh

# Расширенный скрипт для тестирования PostgreSQL
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/postgres-load-test-extended.sh << 'EOF'
#!/bin/bash

echo "Расширенное нагрузочное тестирование PostgreSQL..."

# Настройка переменных
DB_USER=$POSTGRES_USER
DB_NAME="pgbench_test"
SCALE_FACTOR=50  # Размер тестовой БД (множитель)
TEST_DURATION=60  # Длительность тестирования в секундах

# Подготовка тестовой базы данных
echo "Подготовка тестовой базы данных..."
docker exec postgres psql -U $DB_USER -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker exec postgres psql -U $DB_USER -c "CREATE DATABASE $DB_NAME;"

# Инициализация pgbench с разными опциями
echo "Инициализация pgbench..."
docker exec postgres pgbench -i -s $SCALE_FACTOR -U $DB_USER $DB_NAME

# Функция для запуска тестирования и сохранения результатов
run_pgbench_test() {
  local clients=$1
  local jobs=$2
  local description=$3
  local options=$4
  
  echo "=== Тестирование: $description ==="
  echo "Клиенты: $clients, Потоки: $jobs, Опции: $options"
  
  # Запуск теста
  docker exec postgres pgbench -c $clients -j $jobs -T $TEST_DURATION $options -U $DB_USER $DB_NAME
  
  echo "Тест завершен"
  echo ""
}

# Стандартные тесты с разным числом клиентов
for clients in 10 20 50 100; do
  jobs=$(($clients / 5))
  if [ $jobs -lt 2 ]; then jobs=2; fi
  
  run_pgbench_test $clients $jobs "Стандартный тест с $clients клиентами" ""
done

# Тест только чтения
run_pgbench_test 50 4 "Тест только чтения" "-S"

# Тест только записи
run_pgbench_test 50 4 "Тест только записи" "-N"

# Тест с подготовленными запросами
run_pgbench_test 50 4 "Тест с подготовленными запросами" "-M prepared"

# Тест с кастомным скриптом
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/custom_pgbench.sql << 'EOSQL'
\set aid random(1, 100000 * :scale)
\set bid random(1, 1 * :scale)
\set tid random(1, 10 * :scale)
\set delta random(-5000, 5000)
BEGIN;
UPDATE pgbench_accounts SET abalance = abalance + :delta WHERE aid = :aid;
SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP);
COMMIT;
EOSQL

docker cp /tmp/custom_pgbench.sql postgres:/tmp/

# Запуск теста с кастомным скриптом
run_pgbench_test 30 3 "Тест с кастомным скриптом" "-f /tmp/custom_pgbench.sql"

# Тест с использованием pgvector (если установлен)
if docker exec postgres psql -U $DB_USER -d n8n -c "SELECT * FROM pg_extension WHERE extname = 'vector'" | grep -q "vector"; then
  echo "=== Тестирование производительности pgvector ==="
  
  # Создание тестовой таблицы с векторами
  docker exec postgres psql -U $DB_USER -d n8n -c "
    CREATE TABLE IF NOT EXISTS vector_test (
      id SERIAL PRIMARY KEY,
      embedding vector(384),
      metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS vector_test_idx ON vector_test USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
  "
  
  # Заполнение таблицы тестовыми данными
  echo "Заполнение таблицы тестовыми векторами..."
  for i in {1..10}; do
    echo "Вставка партии $i из 10..."
    docker exec postgres psql -U $DB_USER -d n8n -c "
      INSERT INTO vector_test (embedding, metadata)
      SELECT 
        ARRAY_AGG(RANDOM())[:384]::vector AS embedding,
        json_build_object('batch', $i, 'index', s.i) AS metadata
      FROM generate_series(1, 1000) AS s(i)
      GROUP BY s.i;
    "
  done
  
  # Проведение тестовых запросов
  echo "Выполнение тестовых запросов к векторной таблице..."
  
  # Создание временной функции для генерации случайного вектора
  docker exec postgres psql -U $DB_USER -d n8n -c "
    CREATE OR REPLACE FUNCTION random_vector(dim integer) RETURNS vector AS $$
    DECLARE
      result float8[];
    BEGIN
      SELECT ARRAY_AGG(RANDOM()) INTO result FROM generate_series(1, dim);
      RETURN result::vector;
    END;
    $$ LANGUAGE plpgsql;
  "
  
  # Замер времени выполнения запросов поиска ближайших соседей
  docker exec postgres psql -U $DB_USER -d n8n -c "
    \timing on
    
    -- Поиск с использованием индекса
    EXPLAIN ANALYZE
    SELECT id, metadata, embedding <=> random_vector(384) AS distance
    FROM vector_test
    ORDER BY embedding <=> random_vector(384)
    LIMIT 10;
    
    -- Поиск с фильтрацией
    EXPLAIN ANALYZE
    SELECT id, metadata, embedding <=> random_vector(384) AS distance
    FROM vector_test
    WHERE metadata->>'batch' = '5'
    ORDER BY embedding <=> random_vector(384)
    LIMIT 10;
    
    \timing off
  "
  
  # Очистка временной функции
  docker exec postgres psql -U $DB_USER -d n8n -c "DROP FUNCTION random_vector;"
  
  echo "Тестирование pgvector завершено"
else
  echo "Расширение pgvector не установлено, тестирование векторного поиска пропущено"
fi

echo "Расширенное нагрузочное тестирование PostgreSQL завершено!"
EOF

chmod +x /tmp/postgres-load-test-extended.sh
```

**Что анализировать при тестировании PostgreSQL:**
- **Транзакций в секунду (TPS)**: Ключевой показатель производительности БД.
- **Задержка выполнения запросов**: Среднее и максимальное время выполнения.
- **Масштабируемость**: Как меняется TPS при увеличении числа клиентов.
- **Эффективность индексов**: Сравнение запросов с индексами и без них.
- **Потребление ресурсов**: Мониторинг CPU, памяти, I/O и кеша.

**Рекомендации по оптимизации PostgreSQL:**
- Настройте параметры в postgresql.conf (shared_buffers, effective_cache_size, work_mem)
- Используйте правильные индексы для часто выполняемых запросов
- Регулярно проводите VACUUM и ANALYZE для обновления статистики
- Оптимизируйте запросы на основе анализа планов выполнения
- Для pgvector: подберите оптимальные параметры индексов в зависимости от размера данных

#### 9.4.2. Тестирование MariaDB

```bash
# Создание скрипта для тестирования MariaDB
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-mariadb-load.sh << 'EOF'
#!/bin/bash

echo "Подготовка к нагрузочному тестированию MariaDB..."

# Подготовка тестовой базы данных
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "DROP DATABASE IF EXISTS mysqlslap_test;"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE mysqlslap_test;"

# Запуск тестирования с помощью mysqlslap
echo "Запуск тестирования MariaDB..."
docker exec mariadb mysqlslap --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
  --concurrency=10,50,100 --iterations=3 --number-of-queries=1000 \
  --create-schema=mysqlslap_test --query="SELECT SQRT(POW(RAND()*100, 2))"

# Расширенное тестирование с автогенерацией таблиц
docker exec mariadb mysqlslap --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
  --concurrency=10,50 --iterations=2 --number-of-queries=500 \
  --create-schema=mysqlslap_test --auto-generate-sql \
  --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mixed \
  --auto-generate-sql-write-number=100 --auto-generate-sql-execute-number=100

echo "Тестирование MariaDB завершено"
EOF

chmod +x /tmp/test-mariadb-load.sh

# Расширенный скрипт для тестирования MariaDB
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/mariadb-load-test-extended.sh << 'EOF'
#!/bin/bash

echo "Расширенное нагрузочное тестирование MariaDB..."

# Настройка переменных
DB_USER=$MYSQL_USER
DB_PASS=$MYSQL_PASSWORD
TEST_DB="mariadb_load_test"

# Подготовка тестовой базы данных
echo "Подготовка тестовой базы данных..."
docker exec mariadb mysql -u$DB_USER -p$DB_PASS -e "DROP DATABASE IF EXISTS $TEST_DB;"
docker exec mariadb mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE $TEST_DB;"

# Функция для запуска mysqlslap с разными параметрами
run_mysqlslap_test() {
  local concurrency=$1
  local iterations=$2
  local queries=$3
  local description=$4
  local extra_params=$5
  
  echo "=== Тестирование: $description ==="
  echo "Параллельные соединения: $concurrency, Итерации: $iterations, Запросов: $queries"
  
  docker exec mariadb mysqlslap --user=$DB_USER --password=$DB_PASS \
    --concurrency=$concurrency --iterations=$iterations --number-of-queries=$queries \
    --create-schema=$TEST_DB $extra_params
  
  echo "Тест завершен"
  echo ""
}

# Базовые тесты с разным уровнем параллелизма
run_mysqlslap_test "10,50,100" 3 1000 "Простой тест производительности" \
  "--query=\"SELECT SQRT(POW(RAND()*100, 2))\""

# Тест с автогенерацией SQL и смешанной нагрузкой
run_mysqlslap_test "10,50" 2 500 "Тест с автогенерацией таблиц и смешанной нагрузкой" \
  "--auto-generate-sql --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mixed --auto-generate-sql-write-number=100 --auto-generate-sql-execute-number=100"

# Тест только чтения
run_mysqlslap_test "10,50" 2 1000 "Тест только операций чтения" \
  "--auto-generate-sql --auto-generate-sql-load-type=read --auto-generate-sql-execute-number=100"

# Тест только записи
run_mysqlslap_test "10,50" 2 500 "Тест только операций записи" \
  "--auto-generate-sql --auto-generate-sql-load-type=write --auto-generate-sql-write-number=100"

# Тест с пользовательским SQL-скриптом
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/custom_mysql_test.sql << 'EOSQL'
CREATE TABLE IF NOT EXISTS test_table (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  value DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_table (name, value) VALUES (CONCAT('name_', FLOOR(RAND()*1000)), RAND()*1000);
SELECT COUNT(*) FROM test_table;
SELECT AVG(value) FROM test_table;
SELECT name, value FROM test_table ORDER BY value DESC LIMIT 10;
EOSQL

docker cp /tmp/custom_mysql_test.sql mariadb:/tmp/

# Тест с пользовательским скриптом
run_mysqlslap_test "10,20" 2 100 "Тест с пользовательским SQL-скриптом" \
  "--create-schema=$TEST_DB --query=/tmp/custom_mysql_test.sql --delimiter=\";\""

# Проверка производительности различных типов запросов
echo "=== Тестирование различных типов запросов ==="

# Создание тестовой таблицы с данными
docker exec mariadb mysql -u$DB_USER -p$DB_PASS $TEST_DB -e "
  CREATE TABLE test_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50),
    name VARCHAR(100),
    value DECIMAL(10,2),
    text_content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  
  -- Заполнение тестовыми данными
  DELIMITER //
  CREATE PROCEDURE fill_test_data()
  BEGIN
    DECLARE i INT DEFAULT 0;
    WHILE i < 10000 DO
      INSERT INTO test_data (category, name, value, text_content)
      VALUES (
        CASE FLOOR(RAND() * 5)
          WHEN 0 THEN 'Category A'
          WHEN 1 THEN 'Category B'
          WHEN 2 THEN 'Category C'
          WHEN 3 THEN 'Category D'
          ELSE 'Category E'
        END,
        CONCAT('Name ', i),
        ROUND(RAND() * 1000, 2),
        CONCAT('This is a sample text for record ', i, '. It contains some random content for testing purposes.')
      );
      SET i = i + 1;
    END WHILE;
  END //
  DELIMITER ;
  
  CALL fill_test_data();
  DROP PROCEDURE fill_test_data;
  
  -- Создание индексов
  CREATE INDEX idx_category ON test_data(category);
  CREATE INDEX idx_value ON test_data(value);
  CREATE FULLTEXT INDEX idx_text ON test_data(text_content);
"

# Тестирование разных типов запросов
docker exec mariadb mysql -u$DB_USER -p$DB_PASS $TEST_DB -e "
  -- Запрос с агрегацией
  SELECT 'Агрегация' AS 'Тип запроса', NOW() AS 'Начало';
  SELECT category, COUNT(*), AVG(value), MAX(value), MIN(value)
  FROM test_data
  GROUP BY category;
  SELECT NOW() AS 'Окончание';
  
  -- Запрос с сортировкой
  SELECT 'Сортировка' AS 'Тип запроса', NOW() AS 'Начало';
  SELECT id, name, value
  FROM test_data
  ORDER BY value DESC
  LIMIT 100;
  SELECT NOW() AS 'Окончание';
  
  -- Запрос с JOIN (самоприсоединение в данном случае)
  SELECT 'JOIN' AS 'Тип запроса', NOW() AS 'Начало';
  SELECT a.id, a.name, b.name as related_name
  FROM test_data a
  JOIN test_data b ON a.category = b.category AND a.id <> b.id
  WHERE a.value > 900
  LIMIT 100;
  SELECT NOW() AS 'Окончание';
  
  -- Полнотекстовый поиск
  SELECT 'Полнотекстовый поиск' AS 'Тип запроса', NOW() AS 'Начало';
  SELECT id, name, MATCH(text_content) AGAINST('sample random testing') AS relevance
  FROM test_data
  WHERE MATCH(text_content) AGAINST('sample random testing')
  ORDER BY relevance DESC
  LIMIT 100;
  SELECT NOW() AS 'Окончание';
"

echo "Расширенное нагрузочное тестирование MariaDB завершено!"
EOF

chmod +x /tmp/mariadb-load-test-extended.sh
```

**Рекомендации по оптимизации MariaDB:**
- Настройте параметры в my.cnf (innodb_buffer_pool_size, query_cache_size, table_open_cache)
- Используйте правильные типы индексов в зависимости от запросов
- Оптимизируйте запросы на основе анализа планов выполнения (EXPLAIN)
- Регулярно проводите оптимизацию таблиц (OPTIMIZE TABLE)
- Настройте правильные типы таблиц (InnoDB для транзакционных данных, MEMORY для временных данных)

#### 9.4.3. Тестирование Redis

```bash
# Создание скрипта для нагрузочного тестирования Redis
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-redis-load.sh << 'EOF'
#!/bin/bash

echo "Запуск нагрузочного тестирования Redis..."

# Базовый тест производительности с различными операциями
docker exec redis redis-benchmark -q -n 100000 -t set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,zadd,zpopmin,lrange -P 16 -c 50

# Тестирование с разным размером данных
for size in 32 128 512 1024; do
  echo "--- Тестирование с размером данных $size байт ---"
  docker exec redis redis-benchmark -q -n 50000 -d $size -t set,get -P 16 -c 50
  sleep 2
done

# Тестирование с разным числом соединений
for conn in 10 50 100 200; do
  echo "--- Тестирование с $conn соединениями ---"
  docker exec redis redis-benchmark -q -n 50000 -c $conn -t set,get -P 16
  sleep 2
done

echo "Тестирование Redis завершено"
EOF

chmod +x /tmp/test-redis-load.sh

# Расширенный скрипт для тестирования Redis
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/redis-load-test-extended.sh << 'EOF'
#!/bin/bash

echo "Расширенное нагрузочное тестирование Redis..."

# Функция для запуска redis-benchmark с разными параметрами
run_redis_test() {
  local description=$1
  local operations=$2
  local requests=$3
  local clients=$4
  local pipelines=$5
  local data_size=${6:-3}
  local extra_params=${7:-""}
  
  echo "=== Тестирование: $description ==="
  echo "Операции: $operations"
  echo "Запросов: $requests, Клиентов: $clients, Конвейер: $pipelines, Размер данных: $data_size байт"
  
  docker exec redis redis-benchmark -q -n $requests -c $clients -P $pipelines -d $data_size $extra_params -t $operations
  
  echo "Тест завершен"
  echo ""
}

# Общий тест всех основных операций
run_redis_test "Общий тест всех операций" "set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,zadd,zpopmin,lrange" 100000 50 16 3

# Тестирование строковых операций
run_redis_test "Строковые операции" "set,get,mset,mget,incr,decr" 50000 50 16 3

# Тестирование операций со списками
run_redis_test "Операции со списками" "lpush,rpush,lpop,rpop,lrange" 50000 50 16 3

# Тестирование операций с множествами
run_redis_test "Операции с множествами" "sadd,spop,scard,smembers,sismember" 50000 50 16 3

# Тестирование операций с хеш-таблицами
run_redis_test "Операции с хеш-таблицами" "hset,hget,hmset,hmget,hincrby,hgetall" 50000 50 16 3

# Тестирование операций с упорядоченными множествами
run_redis_test "Операции с упорядоченными множествами" "zadd,zcard,zrank,zrange,zpopmin,zpopmax" 50000 50 16 3

# Тестирование с разным размером данных
for size in 32 128 512 1024 4096; do
  run_redis_test "Операции с данными размером $size байт" "set,get" 30000 50 16 $size
done

# Тестирование с разным числом клиентов
for clients in 10 50 100 200 500; do
  run_redis_test "Тест с $clients клиентами" "set,get" 50000 $clients 16 3
done

# Тестирование с разным размером конвейера
for pipeline in 1 8 16 32 64; do
  run_redis_test "Тест с конвейером размером $pipeline" "set,get" 50000 50 $pipeline 3
done

# Тестирование при использовании разных баз данных
for db in 0 1 2; do
  run_redis_test "Тест с использованием базы данных $db" "set,get" 30000 50 16 3 "-n $db"
done

# Тестирование транзакций
echo "=== Тестирование транзакций ==="
docker exec redis bash -c '
redis-cli flushall
for i in $(seq 1 100); do
  redis-cli MULTI
  redis-cli SET "key:$i" "value:$i"
  redis-cli INCR "counter:$i"
  redis-cli SADD "set:$i" "member1" "member2" "member3"
  redis-cli EXEC
done
'

# Нагрузочное тестирование с использованием Lua-скриптов
echo "=== Тестирование Lua-скриптов ==="

# Создание Lua-скрипта для тестирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/redis_script.lua << 'EOLUA'
local key = KEYS[1]
local value = ARGV[1]
redis.call("SET", key, value)
redis.call("INCR", key .. ":counter")
redis.call("SADD", key .. ":set", value)
return redis.call("GET", key)
EOLUA

docker cp /tmp/redis_script.lua redis:/tmp/

# Тестирование выполнения скрипта
docker exec redis bash -c '
SCRIPT_SHA=$(redis-cli SCRIPT LOAD "$(cat /tmp/redis_script.lua)")
echo "Script SHA: $SCRIPT_SHA"
time for i in $(seq 1 1000); do
  redis-cli EVALSHA "$SCRIPT_SHA" 1 "testkey:$i" "testvalue:$i"
done
'

echo "Расширенное нагрузочное тестирование Redis завершено!"
EOF

chmod +x /tmp/redis-load-test-extended.sh
```

**Что анализировать при тестировании Redis:**
- **Операций в секунду (OPS)**: Количество операций, которое Redis может обработать.
- **Задержка**: Время выполнения отдельных операций.
- **Влияние размера данных**: Как производительность меняется с увеличением размера данных.
- **Эффективность конвейеризации**: Насколько повышается производительность при использовании pipelines.
- **Использование памяти**: Мониторинг потребления памяти при различных операциях.

**Рекомендации по оптимизации Redis:**
- Настройте maxmemory и политику очистки (eviction policy) в зависимости от сценария использования
- Используйте конвейерные запросы (pipelines) для уменьшения задержек в сети
- Группируйте связанные операции в транзакции или Lua-скрипты
- Выбирайте подходящие структуры данных для вашего сценария использования
- Используйте операции, работающие со множеством значений (mget, mset), вместо отдельных операций
