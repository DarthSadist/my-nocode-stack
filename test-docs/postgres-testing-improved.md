# Расширенное руководство по тестированию PostgreSQL с pgvector

## 4.2. Тестирование PostgreSQL с pgvector

PostgreSQL с расширением pgvector играет ключевую роль в вашем стеке, обеспечивая хранение данных для n8n и поддерживая векторные вычисления. Тщательное тестирование этого компонента критически важно для обеспечения стабильности и производительности всей системы.

### 4.2.1. Проверка состояния PostgreSQL

```bash
# Проверка состояния PostgreSQL
docker exec postgres pg_isready
```

**Что проверяем и почему это важно:**
- **Отклик сервера**: Команда должна вернуть `/var/run/postgresql:5432 - accepting connections`, что подтверждает работоспособность сервера.
- **Код возврата**: Код 0 означает успешное выполнение, любой другой код указывает на проблемы.
- **Время отклика**: Быстрый отклик указывает на отсутствие проблем с производительностью.

**Возможные проблемы и их решения:**
- **Нет ответа**: Проверьте, запущен ли контейнер: `docker ps | grep postgres`.
- **Отказ в соединении**: Проверьте настройки прав доступа в `pg_hba.conf`.
- **Медленный отклик**: Может указывать на высокую нагрузку или нехватку ресурсов.

**Дополнительная проверка статуса:**
```bash
# Расширенная проверка состояния сервера
docker exec postgres pg_ctl status -D /var/lib/postgresql/data

# Проверка числа активных соединений
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT count(*) FROM pg_stat_activity;"
```

### 4.2.2. Проверка подключения к PostgreSQL

```bash
# Проверка подключения к PostgreSQL
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT version();"
```

**Что проверяем:**
- **Версия PostgreSQL**: Подтверждает успешное подключение и показывает точную версию сервера.
- **Учетные данные**: Проверяет корректность учетных данных (пользователь и пароль).
- **Доступность базы данных**: Убеждается, что указанная база данных существует и доступна.

**Ожидаемый результат:**
```
                                                      version                                                      
-------------------------------------------------------------------------------------------------------------------
 PostgreSQL 15.4 (Debian 15.4-2.pgdg120+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
(1 row)
```

**Проверка других параметров подключения:**
```bash
# Проверка настроек соединения
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SHOW max_connections;"

# Проверка текущих активных соединений
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT datname, usename, client_addr, state FROM pg_stat_activity;"
```

### 4.2.3. Проверка наличия расширения pgvector

```bash
# Проверка наличия расширения pgvector
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

**Что проверяем:**
- **Наличие расширения**: Результат должен содержать строку с информацией о расширении vector.
- **Версия расширения**: Должна соответствовать ожидаемой (v0.6.0 или новее).

**Ожидаемый результат:**
```
 extname | extowner | extnamespace | extrelocatable | extversion | extconfig | extcondition 
---------+----------+--------------+----------------+------------+-----------+--------------
 vector  |       10 |           11 | t              | 0.6.0      |           | 
(1 row)
```

**Действия при отсутствии расширения:**
```bash
# Установка расширения pgvector, если оно отсутствует
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Проверка установки
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

### 4.2.4. Тестирование создания и использования векторов

```bash
# Тестирование создания и использования векторов
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
CREATE TABLE IF NOT EXISTS test_vectors (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM test_vectors;
SELECT id, embedding <-> '[3,3,3]' AS distance FROM test_vectors ORDER BY distance;
DROP TABLE test_vectors;
"
```

**Что проверяем:**
- **Создание таблицы с векторным полем**: Проверяет возможность определения поля типа vector.
- **Вставка векторных данных**: Подтверждает корректное сохранение векторов.
- **Выполнение векторного поиска**: Проверяет работоспособность оператора расстояния (<->).
- **Сортировка по расстоянию**: Подтверждает правильность вычисления расстояний.

**Ожидаемый результат:**
```
 id | embedding 
----+-----------
  1 | [1,2,3]
  2 | [4,5,6]
(2 rows)

 id | distance 
----+----------
  1 |   1.7321
  2 |   5.1962
(2 rows)
```

**Расширенное тестирование векторных операций:**
```bash
# Тестирование различных методов векторного поиска
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
CREATE TABLE IF NOT EXISTS test_vectors_extended (id serial PRIMARY KEY, description text, embedding vector(3));
INSERT INTO test_vectors_extended (description, embedding) VALUES 
  ('Vector 1', '[1,2,3]'), 
  ('Vector 2', '[4,5,6]'),
  ('Vector 3', '[7,8,9]'),
  ('Vector 4', '[0.1,0.2,0.3]'),
  ('Vector 5', '[0.4,0.5,0.6]');

-- Ближайшие соседи с использованием точного поиска
SELECT id, description, embedding <-> '[2,2,2]' AS distance 
FROM test_vectors_extended 
ORDER BY distance 
LIMIT 3;

-- Использование индекса для ускорения поиска
CREATE INDEX idx_test_vectors_extended ON test_vectors_extended USING ivfflat (embedding vector_cosine_ops);

-- Ближайшие соседи с использованием косинусного расстояния
SELECT id, description, embedding <=> '[2,2,2]' AS cosine_distance 
FROM test_vectors_extended 
ORDER BY cosine_distance 
LIMIT 3;

DROP TABLE test_vectors_extended;
"
```

### 4.2.5. Тестирование производительности PostgreSQL

#### 4.2.5.1. Базовые тесты производительности

```bash
# Тестирование времени выполнения запросов
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
-- Создание тестовой таблицы
CREATE TABLE IF NOT EXISTS perf_test (id serial PRIMARY KEY, data text, created_at timestamp DEFAULT current_timestamp);

-- Вставка тестовых данных
INSERT INTO perf_test (data) 
SELECT 'Test data ' || g FROM generate_series(1, 10000) g;

-- Замер времени выполнения запроса
\\timing on
SELECT count(*) FROM perf_test;
SELECT * FROM perf_test ORDER BY id DESC LIMIT 10;
\\timing off

-- Очистка тестовых данных
DROP TABLE perf_test;
"
```

**Что проверяем:**
- **Время выполнения запросов**: Оценка базовой производительности.
- **Масштабируемость**: Как система справляется с большим объемом данных.
- **Скорость отклика**: Время выполнения простых и сложных запросов.

**Интерпретация результатов:**
- Время выполнения COUNT(*) должно быть менее 50 мс для 10,000 записей
- Запрос с сортировкой должен выполняться менее 100 мс
- Любое значительное отклонение может указывать на проблемы с настройками или ресурсами

#### 4.2.5.2. Тестирование векторных индексов

```bash
# Тестирование производительности векторного поиска
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
-- Создание тестовой таблицы с векторами
CREATE TABLE IF NOT EXISTS vector_perf_test (
  id serial PRIMARY KEY,
  description text,
  embedding vector(384)  -- Типичная размерность для embeddings
);

-- Вставка тестовых данных (генерация случайных векторов)
INSERT INTO vector_perf_test (description, embedding)
SELECT 
  'Vector ' || g,
  (SELECT array_agg(random())::real[] FROM generate_series(1, 384))
FROM generate_series(1, 1000) g;

-- Замер времени поиска без индекса
\\timing on
SELECT id, embedding <-> (
  SELECT array_agg(random())::real[] FROM generate_series(1, 384)
) AS distance
FROM vector_perf_test
ORDER BY distance
LIMIT 10;
\\timing off

-- Создание индекса
CREATE INDEX ON vector_perf_test USING ivfflat (embedding vector_l2_ops) WITH (lists = 100);

-- Замер времени поиска с индексом
\\timing on
SELECT id, embedding <-> (
  SELECT array_agg(random())::real[] FROM generate_series(1, 384)
) AS distance
FROM vector_perf_test
ORDER BY distance
LIMIT 10;
\\timing off

-- Очистка тестовых данных
DROP TABLE vector_perf_test;
"
```

**Что проверяем:**
- **Скорость векторного поиска**: Сравнение производительности с индексом и без.
- **Эффективность индексов**: Насколько индекс ускоряет поиск ближайших векторов.
- **Масштабируемость**: Как система работает с увеличением размерности и количества векторов.

**Ожидаемые результаты:**
- Поиск с использованием индекса должен быть в 10-100 раз быстрее
- Время поиска должно оставаться приемлемым даже при большом количестве векторов

### 4.2.6. Тестирование резервного копирования и восстановления

```bash
# Создание тестовой базы данных для резервного копирования
docker exec postgres psql -U $POSTGRES_USER -d postgres -c "
CREATE DATABASE backup_test;
\\c backup_test
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE test_table (id serial PRIMARY KEY, name text, embedding vector(3));
INSERT INTO test_table (name, embedding) VALUES 
  ('Test 1', '[1,2,3]'), 
  ('Test 2', '[4,5,6]');
"

# Создание резервной копии базы данных
docker exec postgres pg_dump -U $POSTGRES_USER backup_test > /tmp/backup_test.sql

# Восстановление из резервной копии
docker exec postgres psql -U $POSTGRES_USER -d postgres -c "DROP DATABASE IF EXISTS restore_test; CREATE DATABASE restore_test;"
cat /tmp/backup_test.sql | docker exec -i postgres psql -U $POSTGRES_USER restore_test

# Проверка восстановленных данных
docker exec postgres psql -U $POSTGRES_USER -d restore_test -c "SELECT * FROM test_table;"

# Проверка векторных функций в восстановленной базе
docker exec postgres psql -U $POSTGRES_USER -d restore_test -c "
SELECT id, name, embedding <-> '[2,2,2]' AS distance 
FROM test_table 
ORDER BY distance;
"

# Очистка тестовых баз данных
docker exec postgres psql -U $POSTGRES_USER -d postgres -c "
DROP DATABASE IF EXISTS backup_test;
DROP DATABASE IF EXISTS restore_test;
"
```

**Что проверяем:**
- **Процесс резервного копирования**: Корректность создания дампа базы.
- **Процесс восстановления**: Возможность полного восстановления из дампа.
- **Целостность данных**: Соответствие данных до и после восстановления.
- **Работа расширений**: Корректное восстановление расширения vector и его функций.

**Особое внимание уделяем:**
- Корректному восстановлению векторных полей
- Сохранению индексов и других объектов базы данных
- Времени выполнения резервного копирования и восстановления

### 4.2.7. Тестирование настроек безопасности

```bash
# Проверка настроек аутентификации
docker exec postgres cat /var/lib/postgresql/data/pg_hba.conf

# Проверка списка ролей и их привилегий
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles
ORDER BY rolname;
"

# Проверка прав на объекты базы данных
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT table_schema, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = current_user
ORDER BY table_schema, table_name, privilege_type;
"
```

**Что проверяем:**
- **Настройки аутентификации**: Методы аутентификации в pg_hba.conf.
- **Роли и привилегии**: Права доступа пользователей и ролей.
- **Права на объекты**: Контроль доступа к таблицам и другим объектам.

**Рекомендации по безопасности:**
- Используйте метод аутентификации md5 или scram-sha-256 вместо trust
- Ограничьте сетевой доступ в pg_hba.conf только необходимыми хостами
- Следуйте принципу минимальных привилегий для пользователей

### 4.2.8. Тестирование работы под нагрузкой

```bash
# Создание тестовой таблицы для нагрузочного тестирования
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
CREATE TABLE IF NOT EXISTS load_test (
  id serial PRIMARY KEY,
  data text,
  vector_data vector(10),
  created_at timestamp DEFAULT current_timestamp
);

-- Создание индекса для векторного поля
CREATE INDEX ON load_test USING ivfflat (vector_data);
"

# Скрипт для нагрузочного тестирования (запуск множества параллельных INSERT)
cat > /tmp/postgres-load-test.sh << EOF
#!/bin/bash
for i in {1..10}; do
  docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
  INSERT INTO load_test (data, vector_data)
  SELECT 
    'Batch $i - Entry ' || g,
    (SELECT array_agg(random())::real[] FROM generate_series(1, 10))
  FROM generate_series(1, 1000) g;
  " &
done
wait
echo "Load test completed"
EOF

chmod +x /tmp/postgres-load-test.sh

# Запуск нагрузочного тестирования и мониторинг ресурсов
docker stats postgres --no-stream
/tmp/postgres-load-test.sh
docker stats postgres --no-stream

# Проверка результатов вставки
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT count(*) FROM load_test;

-- Проверка времени выполнения запросов под нагрузкой
\\timing on
SELECT COUNT(*) FROM load_test WHERE id % 100 = 0;
SELECT id, data FROM load_test ORDER BY id DESC LIMIT 10;
SELECT id, data, vector_data <-> (SELECT array_agg(random())::real[] FROM generate_series(1, 10)) AS distance 
FROM load_test ORDER BY distance LIMIT 5;
\\timing off

-- Очистка тестовых данных
DROP TABLE load_test;
"
```

**Что проверяем:**
- **Производительность при параллельных операциях**: Как система справляется с множеством одновременных запросов.
- **Использование ресурсов**: Потребление CPU, памяти и I/O под нагрузкой.
- **Стабильность**: Отсутствие сбоев или значительного снижения производительности.

**Ожидаемые результаты:**
- Успешное завершение всех параллельных операций
- Приемлемое время отклика даже под нагрузкой
- Отсутствие ошибок в логах

### 4.2.9. Проверка настроек и оптимизация

```bash
# Проверка текущих настроек PostgreSQL
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SHOW max_connections;
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW random_page_cost;
SHOW effective_io_concurrency;
SHOW max_worker_processes;
SHOW max_parallel_workers;
SHOW max_parallel_workers_per_gather;
"

# Проверка статистики базы данных
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT datname, numbackends, xact_commit, xact_rollback, blks_read, blks_hit, tup_returned, tup_fetched
FROM pg_stat_database
WHERE datname = '$POSTGRES_DB';
"

# Проверка размера базы данных и таблиц
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT pg_size_pretty(pg_database_size('$POSTGRES_DB')) AS db_size;

SELECT 
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  pg_size_pretty(pg_table_size(relid)) AS table_size,
  pg_size_pretty(pg_indexes_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;
"
```

**Что проверяем:**
- **Настройки производительности**: Оптимальность параметров для текущей нагрузки и доступных ресурсов.
- **Статистика использования**: Соотношение операций чтения/записи, количество транзакций.
- **Размеры объектов**: Объем данных и индексов для выявления потенциальных проблем.

**Рекомендации по оптимизации:**
- Настройте `shared_buffers` на 25% от доступной RAM
- Увеличьте `work_mem` для сложных операций сортировки и соединения
- Оптимизируйте `effective_cache_size` в зависимости от доступной RAM
- Настройте параллельное выполнение запросов через `max_parallel_workers_per_gather`

### 4.2.10. Тестирование устойчивости к сбоям

```bash
# Тестирование восстановления после принудительного завершения
docker stop postgres
docker start postgres
sleep 5
docker exec postgres pg_isready

# Проверка целостности данных после перезапуска
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
CREATE TABLE IF NOT EXISTS crash_test (id serial PRIMARY KEY, data text);
INSERT INTO crash_test (data) VALUES ('Before crash test');
"

# Имитация сбоя (грубое завершение процесса)
docker kill --signal=SIGKILL postgres
docker start postgres
sleep 10

# Проверка доступности после перезапуска
docker exec postgres pg_isready

# Проверка целостности данных
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
SELECT * FROM crash_test;
INSERT INTO crash_test (data) VALUES ('After crash test');
SELECT * FROM crash_test;
DROP TABLE crash_test;
"
```

**Что проверяем:**
- **Восстановление после сбоя**: Способность системы автоматически восстанавливаться после непредвиденного завершения.
- **Целостность данных**: Отсутствие повреждения данных при аварийном завершении.
- **Время восстановления**: Скорость восстановления работоспособности после сбоя.

**Ожидаемые результаты:**
- PostgreSQL должен успешно восстановиться после SIGKILL
- WAL (Write-Ahead Logging) должен обеспечить сохранность всех подтвержденных транзакций
- После восстановления должны быть доступны все данные, существовавшие до сбоя

### 4.2.11. Дополнительное тестирование pgvector

#### 4.2.11.1. Тестирование различных методов индексирования

```bash
# Тестирование различных методов индексирования в pgvector
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
-- Создание тестовой таблицы с векторами
CREATE TABLE IF NOT EXISTS index_test (
  id serial PRIMARY KEY,
  description text,
  embedding vector(128)
);

-- Вставка тестовых данных
INSERT INTO index_test (description, embedding)
SELECT 
  'Vector ' || g,
  (SELECT array_agg(random())::real[] FROM generate_series(1, 128))
FROM generate_series(1, 10000) g;

-- Тест 1: Без индекса
\\timing on
SELECT id, embedding <-> (
  SELECT array_agg(random())::real[] FROM generate_series(1, 128)
) AS distance
FROM index_test
ORDER BY distance
LIMIT 10;
\\timing off

-- Тест 2: Индекс IVFFLAT (приближенный поиск)
CREATE INDEX ON index_test USING ivfflat (embedding vector_l2_ops) WITH (lists = 100);
\\timing on
SET ivfflat.probes = 10;
SELECT id, embedding <-> (
  SELECT array_agg(random())::real[] FROM generate_series(1, 128)
) AS distance
FROM index_test
ORDER BY distance
LIMIT 10;
\\timing off
DROP INDEX index_test_embedding_idx;

-- Тест 3: Индекс HNSW (иерархическая навигационная структура малого мира)
CREATE INDEX ON index_test USING hnsw (embedding vector_l2_ops);
\\timing on
SELECT id, embedding <-> (
  SELECT array_agg(random())::real[] FROM generate_series(1, 128)
) AS distance
FROM index_test
ORDER BY distance
LIMIT 10;
\\timing off

-- Очистка тестовых данных
DROP TABLE index_test;
"
```

**Что проверяем:**
- **Производительность различных типов индексов**: Сравнение IVFFLAT и HNSW для векторного поиска.
- **Точность поиска**: Насколько точно приближенные методы находят ближайшие векторы.
- **Время создания индекса**: Скорость построения различных типов индексов.

**Интерпретация результатов:**
- IVFFLAT обычно быстрее строится, но может давать менее точные результаты
- HNSW обычно обеспечивает более точные результаты и быстрый поиск, но дольше строится
- Выбор типа индекса зависит от конкретных требований к точности и скорости

#### 4.2.11.2. Тестирование различных метрик расстояния

```bash
# Тестирование различных метрик расстояния в pgvector
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "
-- Создание тестовой таблицы с векторами
CREATE TABLE IF NOT EXISTS distance_test (
  id serial PRIMARY KEY,
  description text,
  embedding vector(5)
);

-- Вставка тестовых данных
INSERT INTO distance_test (description, embedding) VALUES 
  ('Vector 1', '[1,0,0,0,0]'),
  ('Vector 2', '[0,1,0,0,0]'),
  ('Vector 3', '[0,0,1,0,0]'),
  ('Vector 4', '[1,1,0,0,0]'),
  ('Vector 5', '[0.5,0.5,0.5,0.5,0.5]');

-- Тест метрики L2 (Евклидово расстояние)
SELECT id, description, embedding <-> '[1,1,1,0,0]' AS l2_distance
FROM distance_test
ORDER BY l2_distance;

-- Тест метрики косинусного расстояния
SELECT id, description, embedding <=> '[1,1,1,0,0]' AS cosine_distance
FROM distance_test
ORDER BY cosine_distance;

-- Тест метрики внутреннего произведения (скалярного произведения)
SELECT id, description, embedding <#> '[1,1,1,0,0]' AS inner_product_distance
FROM distance_test
ORDER BY inner_product_distance;

-- Очистка тестовых данных
DROP TABLE distance_test;
"
```

**Что проверяем:**
- **Различные метрики расстояния**: Сравнение результатов L2, косинусного расстояния и внутреннего произведения.
- **Применимость метрик**: Какая метрика лучше подходит для конкретных типов данных.
- **Корректность вычислений**: Правильность расчета расстояний согласно формулам.

**Практические применения:**
- L2 (Евклидово расстояние): для поиска похожих по абсолютным значениям векторов
- Косинусное расстояние: для поиска семантически похожих векторов (с учетом направления, но не длины)
- Внутреннее произведение: для специфических задач, когда важна направленность векторов
