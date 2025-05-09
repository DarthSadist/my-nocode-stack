# Расширенное руководство по тестированию Redis

## 4.6. Тестирование Redis

Redis - это высокопроизводительное хранилище данных в оперативной памяти, которое играет важную роль в вашем стеке в качестве кеша, брокера сообщений и системы для хранения временных данных. Тщательное тестирование Redis необходимо для обеспечения оптимальной производительности и надежности всей системы.

### 4.6.1. Проверка доступности Redis

```bash
# Проверка доступности Redis через CLI
docker exec redis redis-cli ping
```

**Ожидаемый результат:**
```
PONG
```

**Расширенная проверка подключения:**
```bash
# Проверка соединения с Redis и его конфигурации
docker exec redis redis-cli INFO server
```

**Что проверять и почему это важно:**
- **Ответ PONG**: Подтверждает, что Redis-сервер запущен и отвечает на запросы.
- **Версия Redis**: Убедитесь, что используется актуальная версия.
- **Время работы (uptime)**: Проверьте, как долго сервер работает без перезапусков.
- **Используемая память**: Важно для оценки текущей нагрузки.
- **Количество клиентов**: Показывает, сколько подключений активно.

**Проверка через другие контейнеры:**
```bash
# Проверка доступности Redis из других сервисов
docker exec wordpress redis-cli -h redis ping
docker exec n8n redis-cli -h redis ping
docker exec flowise redis-cli -h redis ping
```

### 4.6.2. Проверка логов Redis

```bash
# Просмотр логов Redis
docker logs redis --tail 100
```

**Что искать в логах:**
- **Ошибки и предупреждения**: Обратите внимание на сообщения "WARNING" или "ERROR".
- **Сообщения о подключениях**: Анализируйте информацию о клиентских соединениях.
- **Использование памяти**: Обратите внимание на сообщения о достижении лимитов памяти.
- **Активность снапшотов**: Проверьте записи о создании снапшотов (RDB) и AOF-журналов.

**Дополнительные команды для анализа логов:**
```bash
# Поиск ошибок в логах Redis
docker logs redis 2>&1 | grep -i "error\|warning\|crash\|fail"

# Мониторинг логов в реальном времени
docker logs -f redis
```

### 4.6.3. Базовые функциональные тесты Redis

#### 4.6.3.1. Проверка операций чтения и записи

```bash
# Базовый тест записи и чтения
docker exec redis redis-cli SET test_key "Тестовое значение"
docker exec redis redis-cli GET test_key
```

**Ожидаемый результат:**
```
OK
"Тестовое значение"
```

**Расширенное тестирование типов данных:**
```bash
# Тестирование строк (Strings)
docker exec redis redis-cli SET string_key "Пример строки"
docker exec redis redis-cli GET string_key

# Тестирование списков (Lists)
docker exec redis redis-cli LPUSH list_key "элемент1" "элемент2" "элемент3"
docker exec redis redis-cli LRANGE list_key 0 -1

# Тестирование множеств (Sets)
docker exec redis redis-cli SADD set_key "значение1" "значение2" "значение3"
docker exec redis redis-cli SMEMBERS set_key

# Тестирование хешей (Hashes)
docker exec redis redis-cli HSET hash_key поле1 "значение1" поле2 "значение2"
docker exec redis redis-cli HGETALL hash_key

# Тестирование упорядоченных множеств (Sorted Sets)
docker exec redis redis-cli ZADD sorted_key 1 "A" 2 "B" 3 "C"
docker exec redis redis-cli ZRANGE sorted_key 0 -1 WITHSCORES
```

#### 4.6.3.2. Проверка времени жизни ключей (TTL)

```bash
# Тестирование TTL (Time-to-Live)
docker exec redis redis-cli SET ttl_key "временное значение" EX 10
docker exec redis redis-cli TTL ttl_key
sleep 5
docker exec redis redis-cli TTL ttl_key
sleep 6
docker exec redis redis-cli EXISTS ttl_key
```

**Ожидаемый результат:**
```
OK
(integer) 10
(integer) 5
(integer) 0
```

**Проверка работы с постоянными ключами:**
```bash
# Тестирование сохранения ключей
docker exec redis redis-cli SET persist_key "постоянное значение" EX 30
docker exec redis redis-cli PERSIST persist_key
docker exec redis redis-cli TTL persist_key
```

**Ожидаемый результат:**
```
OK
(integer) 1
(integer) -1
```

### 4.6.4. Тестирование производительности Redis

#### 4.6.4.1. Базовый тест производительности

```bash
# Базовый тест производительности с помощью redis-benchmark
docker exec redis redis-benchmark -q -n 10000 -c 50 -P 5 -t set,get
```

**Что анализировать:**
- **Запросы в секунду (RPS)**: Показывает скорость обработки операций.
- **Задержка (Latency)**: Оценка времени отклика на запросы.
- **Разница между операциями**: Сравнение производительности разных типов команд.

#### 4.6.4.2. Расширенное тестирование производительности

```bash
# Скрипт для более детального тестирования производительности
cat > /tmp/redis-perf-test.sh << 'EOF'
#!/bin/bash

echo "Redis Performance Test"
echo "======================="

# Тестирование различных размеров данных
for size in 10 100 1000 10000; do
  echo ""
  echo "Тестирование с данными размером $size байт"
  docker exec redis redis-benchmark -q -n 5000 -d $size -t set,get,lpush,lpop,sadd,spop,zadd,zpopmin
done

# Тестирование с разным числом параллельных соединений
for clients in 10 50 100 200; do
  echo ""
  echo "Тестирование с $clients параллельными клиентами"
  docker exec redis redis-benchmark -q -n 5000 -c $clients -t set,get,lpush,lpop,sadd,spop
done

# Тестирование с разными размерами пакетов (pipeline)
for pipeline in 1 5 10 50; do
  echo ""
  echo "Тестирование с размером пакета $pipeline команд"
  docker exec redis redis-benchmark -q -n 5000 -P $pipeline -t set,get
done

echo ""
echo "Тестирование производительности завершено"
EOF

chmod +x /tmp/redis-perf-test.sh
/tmp/redis-perf-test.sh
```

**Что анализировать:**
- **Зависимость от размера данных**: Как производительность меняется с увеличением размера данных.
- **Масштабируемость**: Как система справляется с увеличением числа параллельных клиентов.
- **Эффективность пакетной обработки**: Насколько улучшается производительность при использовании пакетов команд.

### 4.6.5. Тестирование использования памяти

```bash
# Проверка текущего использования памяти
docker exec redis redis-cli INFO memory
```

**Что проверять:**
- **used_memory**: Общее количество памяти, используемой Redis.
- **used_memory_peak**: Пиковое использование памяти с момента запуска.
- **used_memory_rss**: Физическая память, выделенная для процесса Redis.
- **mem_fragmentation_ratio**: Отношение used_memory_rss к used_memory (важно для оценки фрагментации памяти).

**Тестирование поведения при нехватке памяти:**
```bash
# Тестирование политики вытеснения (eviction policy)
docker exec redis redis-cli CONFIG GET maxmemory-policy
docker exec redis redis-cli CONFIG GET maxmemory

# Создание большого количества данных для проверки вытеснения
docker exec redis bash -c 'for i in {1..10000}; do redis-cli SET key$i value$i; done'
```

**Тестирование очистки памяти:**
```bash
# Ручная очистка памяти
docker exec redis redis-cli FLUSHALL
docker exec redis redis-cli INFO memory
```

### 4.6.6. Тестирование персистентности данных

#### 4.6.6.1. Проверка конфигурации персистентности

```bash
# Проверка настроек RDB и AOF
docker exec redis redis-cli CONFIG GET save
docker exec redis redis-cli CONFIG GET appendonly
docker exec redis redis-cli CONFIG GET appendfsync
```

#### 4.6.6.2. Тестирование снапшотов RDB

```bash
# Создание тестовых данных
docker exec redis redis-cli SET rdb_test_key "Значение для теста RDB"

# Создание снапшота вручную
docker exec redis redis-cli SAVE

# Проверка создания файла dump.rdb
docker exec redis ls -la /data/dump.rdb

# Очистка данных и проверка восстановления после перезапуска
docker exec redis redis-cli FLUSHALL
docker exec redis redis-cli GET rdb_test_key
docker restart redis
sleep 5
docker exec redis redis-cli GET rdb_test_key
```

#### 4.6.6.3. Тестирование AOF (если включено)

```bash
# Проверка, включен ли AOF
APPENDONLY=$(docker exec redis redis-cli CONFIG GET appendonly | awk 'NR==2')

if [ "$APPENDONLY" = "yes" ]; then
    # Создание тестовых данных для AOF
    docker exec redis redis-cli SET aof_test_key "Значение для теста AOF"
    
    # Принудительное обновление AOF файла
    docker exec redis redis-cli BGREWRITEAOF
    sleep 2
    
    # Проверка создания appendonly.aof
    docker exec redis ls -la /data/appendonly.aof
    
    # Очистка данных и проверка восстановления после перезапуска
    docker exec redis redis-cli FLUSHALL
    docker restart redis
    sleep 5
    docker exec redis redis-cli GET aof_test_key
fi
```

### 4.6.7. Тестирование высокой доступности (если настроена репликация)

```bash
# Проверка, настроена ли репликация
ROLE=$(docker exec redis redis-cli INFO replication | grep role | cut -d: -f2 | tr -d '[:space:]')

if [ "$ROLE" = "master" ]; then
    echo "Redis настроен как мастер"
    
    # Проверка реплик
    docker exec redis redis-cli INFO replication | grep connected_slaves
    
    # Тестирование репликации данных (если есть реплики)
    docker exec redis redis-cli SET repl_test_key "Тест репликации"
    
    # Нужно проверить появление данных на репликах
    # (предполагается, что есть доступ к репликам)
    # docker exec redis-replica redis-cli GET repl_test_key
fi
```

### 4.6.8. Тестирование интеграций с другими сервисами

#### 4.6.8.1. Интеграция с WordPress (если используется для кеширования)

```bash
# Проверка подключения WordPress к Redis
docker exec wordpress redis-cli -h redis ping

# Проверка наличия объектов кеша WordPress в Redis (если настроено)
docker exec redis redis-cli KEYS "wp_*"
```

#### 4.6.8.2. Интеграция с n8n (если используется для очередей или кеширования)

```bash
# Проверка подключения n8n к Redis
docker exec n8n redis-cli -h redis ping

# Проверка ключей n8n в Redis (если используется)
docker exec redis redis-cli KEYS "n8n:*"
```

#### 4.6.8.3. Интеграция с Flowise (если используется для состояний или кеширования)

```bash
# Проверка подключения Flowise к Redis
docker exec flowise redis-cli -h redis ping

# Проверка ключей Flowise в Redis (если используется)
docker exec redis redis-cli KEYS "flowise:*"
```

### 4.6.9. Тестирование безопасности Redis

```bash
# Проверка конфигурации безопасности
docker exec redis redis-cli CONFIG GET bind
docker exec redis redis-cli CONFIG GET protected-mode
docker exec redis redis-cli CONFIG GET requirepass

# Проверка пароля (если настроен)
PASSWORD=$(docker exec redis redis-cli CONFIG GET requirepass | awk 'NR==2')
if [ -n "$PASSWORD" ] && [ "$PASSWORD" != '""' ]; then
    # Тестирование доступа с паролем
    docker exec redis redis-cli -a "$PASSWORD" ping
    
    # Тестирование доступа без пароля (должно завершиться ошибкой)
    docker exec redis redis-cli ping
fi
```

**Дополнительные проверки безопасности:**
```bash
# Проверка доступных команд (на случай, если некоторые команды отключены)
docker exec redis redis-cli COMMAND LIST

# Проверка ограничений на команды CONFIG
docker exec redis redis-cli CONFIG GET rename-command
```

### 4.6.10. Тестирование восстановления после сбоев

```bash
# Имитация сбоя Redis
docker stop redis

# Перезапуск сервиса
docker start redis

# Проверка, что Redis восстановился и данные сохранились
sleep 5
docker exec redis redis-cli ping
docker exec redis redis-cli GET rdb_test_key
```

**Тестирование загрузки с большим объемом данных:**
```bash
# Создание крупного набора данных
docker exec redis bash -c 'for i in {1..50000}; do redis-cli SET loadtest_$i value_$i; done'

# Сохранение данных
docker exec redis redis-cli SAVE

# Перезапуск Redis
docker restart redis

# Измерение времени загрузки
time docker exec redis redis-cli ping
```

### 4.6.11. Мониторинг Redis

```bash
# Скрипт для базового мониторинга Redis
cat > /tmp/redis-monitor.sh << 'EOF'
#!/bin/bash

# Основные метрики для мониторинга Redis
echo "Redis Monitoring Script"
echo "======================="
echo ""

# Использование памяти
echo "Память:"
docker exec redis redis-cli INFO memory | grep used_memory
echo ""

# Клиенты
echo "Клиенты:"
docker exec redis redis-cli INFO clients | grep connected_clients
echo ""

# Статистика команд
echo "Команды:"
docker exec redis redis-cli INFO stats | grep commands_processed
echo ""

# Статистика ключей
echo "Ключи:"
docker exec redis redis-cli INFO keyspace
echo ""

# Мониторинг в режиме реального времени
echo "Активные команды (нажмите Ctrl+C для остановки):"
docker exec -it redis redis-cli MONITOR
EOF

chmod +x /tmp/redis-monitor.sh
```

**Расширенный мониторинг производительности:**
```bash
# Непрерывный мониторинг задержек Redis
docker exec -it redis redis-cli --latency-history
```

### 4.6.12. Тестирование под нагрузкой с использованием реальных паттернов доступа

```bash
# Скрипт для имитации нагрузки, соответствующей реальным паттернам использования
cat > /tmp/redis-workload-test.sh << 'EOF'
#!/bin/bash

# Имитация реальных паттернов доступа к Redis
echo "Тестирование реальных сценариев использования Redis"
echo "===================================================="

# Имитация кеширования веб-страниц (80% чтения, 20% записи)
echo -e "\nИмитация кеширования веб-страниц (80% чтения, 20% записи):"
docker exec redis redis-benchmark -t get,set -n 10000 -P 5 --ratio 4:1 -q

# Имитация хранения сессий (множество маленьких записей с TTL)
echo -e "\nИмитация хранения сессий:"
docker exec redis bash -c '
  for i in {1..1000}; do
    redis-cli SET session_$i "user_data_$i" EX 1800
  done
'
echo "Создано 1000 тестовых сессий с TTL 1800 секунд"

# Имитация счетчиков (множество INCR операций)
echo -e "\nИмитация счетчиков:"
docker exec redis redis-benchmark -t incr -n 10000 -q

# Имитация очередей сообщений (LPUSH/RPOP)
echo -e "\nИмитация очередей сообщений:"
docker exec redis redis-benchmark -t lpush,rpop -n 10000 -q

# Имитация лидерборда (сортированные множества)
echo -e "\nИмитация лидерборда (сортированные множества):"
docker exec redis redis-benchmark -t zadd,zrange -n 5000 -q

echo -e "\nТестирование завершено"
EOF

chmod +x /tmp/redis-workload-test.sh
```

## Рекомендации для эффективного тестирования Redis

1. **Регулярно проверяйте использование памяти**: Redis работает в оперативной памяти, поэтому важно контролировать её использование.

2. **Оптимизируйте политику вытеснения (eviction policy)**: Настройте политику в зависимости от характера ваших данных и требований приложения.

3. **Мониторьте задержки**: Высокие задержки могут указывать на проблемы с настройками или перегрузку сервера.

4. **Тестируйте репликацию**: Если используется репликация, регулярно проверяйте синхронизацию данных между узлами.

5. **Настройте журналирование и персистентность**: Найдите баланс между производительностью и надежностью хранения данных.

6. **Тестируйте поведение при исчерпании памяти**: Убедитесь, что Redis корректно обрабатывает ситуации, когда достигается лимит памяти.

7. **Периодически делайте "горячее" резервное копирование**: Тестируйте процесс резервного копирования без остановки службы.

8. **Тестируйте безопасность**: Особенно, если Redis доступен извне или в недоверенной сети.
