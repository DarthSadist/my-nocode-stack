# Руководство по нагрузочному тестированию стека (Часть 5)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

### 9.5. Комплексное нагрузочное тестирование

#### 9.5.1. Тестирование всего стека одновременно

Комплексное нагрузочное тестирование позволяет оценить поведение всей системы при одновременной нагрузке на все компоненты. Это помогает выявить узкие места и проблемы, которые не проявляются при тестировании отдельных компонентов.

```bash
# Создание скрипта для комплексного нагрузочного тестирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/full-stack-load-test.sh << 'EOF'
#!/bin/bash

echo "Запуск комплексного нагрузочного тестирования всего стека..."

# Проверка готовности системы
echo "Проверка статуса компонентов перед тестированием..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "NAMES"

# Запись состояния ресурсов перед тестированием
echo "Запись исходного состояния ресурсов..."
docker stats --no-stream > /tmp/resources-before-test.txt
free -h > /tmp/memory-before-test.txt
df -h > /tmp/disk-before-test.txt

# Запуск тестов в фоновом режиме
echo "Запуск тестов веб-интерфейсов..."
(ab -n 1000 -c 50 -k -H "Accept-Encoding: gzip, deflate" https://n8n.yourdomain.com/) &
(ab -n 1000 -c 50 -k -H "Accept-Encoding: gzip, deflate" https://flowise.yourdomain.com/) &
(ab -n 1000 -c 50 -k -H "Accept-Encoding: gzip, deflate" https://wordpress.yourdomain.com/) &

# Запуск теста Redis
echo "Запуск теста Redis..."
(docker exec redis redis-benchmark -q -n 10000 -t set,get -P 16 -c 50) &

# Запуск теста PostgreSQL
echo "Запуск теста PostgreSQL..."
(docker exec postgres pgbench -c 20 -j 2 -T 30 -U $POSTGRES_USER n8n) &

# Запуск теста MariaDB
echo "Запуск теста MariaDB..."
(docker exec mariadb mysqlslap --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
  --concurrency=20 --iterations=2 --number-of-queries=1000 \
  --create-schema=$MYSQL_DATABASE --auto-generate-sql) &

# Запуск теста Qdrant
echo "Запуск теста Qdrant..."
{
  # Генерация случайного вектора для запросов
  vector="["
  for i in {1..384}; do
    vector+="$(printf "%.3f" $(echo "scale=3; $RANDOM/32767" | bc -l))"
    if [ $i -lt 384 ]; then
      vector+=", "
    fi
  done
  vector+="]"
  
  # Выполнение поисковых запросов
  for i in {1..100}; do
    curl -s -X POST "http://localhost:6333/collections/load_test/points/search" \
      -H "Content-Type: application/json" \
      -d '{
        "vector": '$vector',
        "limit": 10
      }' > /dev/null
    sleep 0.5
  done
} &

# Запуск теста API
echo "Запуск тестов API..."
{
  # Тест n8n API
  hey -n 200 -c 20 -m POST \
    -H "Content-Type: application/json" \
    -d '{"test":"data","timestamp":"'$(date -Iseconds)'"}' \
    https://n8n.yourdomain.com/webhook/test-load
  
  # Тест WordPress API
  hey -n 200 -c 20 -m GET https://wordpress.yourdomain.com/wp-json/wp/v2/posts
  
  # Тест Flowise API
  FLOW_ID=$(curl -s https://flowise.yourdomain.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
  if [ -n "$FLOW_ID" ]; then
    hey -n 50 -c 5 -m POST \
      -H "Content-Type: application/json" \
      -d '{
        "question": "Тестовый запрос для комплексного нагрузочного тестирования",
        "overrideConfig": {
          "sessionId": "complex-load-test-session"
        }
      }' \
      "https://flowise.yourdomain.com/api/v1/prediction/$FLOW_ID"
  fi
} &

# Ожидание завершения всех тестов
echo "Тесты запущены. Ожидание завершения..."
wait

# Запись состояния ресурсов после тестирования
echo "Запись состояния ресурсов после тестирования..."
docker stats --no-stream > /tmp/resources-after-test.txt
free -h > /tmp/memory-after-test.txt
df -h > /tmp/disk-after-test.txt

echo "Комплексное нагрузочное тестирование завершено"
echo "Сравните результаты в файлах /tmp/resources-before-test.txt и /tmp/resources-after-test.txt"
EOF

chmod +x /tmp/full-stack-load-test.sh
```

**Что анализировать при комплексном тестировании:**
- **Взаимное влияние компонентов**: Насколько снижается производительность каждого компонента при одновременной нагрузке.
- **Использование общих ресурсов**: Конкуренция за CPU, память, диск и сеть.
- **Стабильность системы**: Отсутствие сбоев и ошибок при комплексной нагрузке.
- **Восстановление после нагрузки**: Как быстро система возвращается в нормальное состояние.

**Рекомендации по балансировке ресурсов:**
- Определите приоритетные компоненты и выделите им больше ресурсов
- Настройте ограничения ресурсов в Docker для защиты критически важных сервисов
- Масштабируйте компоненты с высокой нагрузкой горизонтально или вертикально
- Внедрите механизмы балансировки нагрузки для компонентов с высоким трафиком

#### 7.5.2. Профилирование узких мест и оптимизация

Для выявления узких мест в системе и их последующей оптимизации важно собрать детальную информацию о производительности каждого компонента.

```bash
# Создание скрипта для выявления узких мест
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/identify-bottlenecks.sh << 'EOF'
#!/bin/bash

echo "Анализ производительности системы и выявление узких мест..."

# Функция для добавления разделителей
separator() {
  echo "================================================================="
}

# Проверка использования CPU
separator
echo "=== Использование CPU ==="
top -b -n 1 | head -20

# Проверка процессов с наибольшим использованием CPU
separator
echo "=== Процессы с наибольшим использованием CPU ==="
ps aux --sort=-%cpu | head -10

# Проверка использования памяти
separator
echo "=== Использование памяти ==="
free -h

# Проверка процессов с наибольшим использованием памяти
separator
echo "=== Процессы с наибольшим использованием памяти ==="
ps aux --sort=-%mem | head -10

# Проверка использования диска
separator
echo "=== Использование диска и I/O ==="
df -h
iostat -x 1 5

# Проверка файловых операций
separator
echo "=== Файловые операции для контейнеров ==="
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker exec $container lsof -n | wc -l
done

# Проверка сетевых подключений
separator
echo "=== Сетевые подключения ==="
netstat -tunapl | grep ESTABLISHED | wc -l
netstat -tunapl | grep docker | wc -l

# Детальный анализ сетевых соединений
separator
echo "=== Детальный анализ сетевых соединений ==="
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker exec $container netstat -tunapl 2>/dev/null | grep ESTABLISHED | wc -l
done

# Проверка нагрузки на контейнеры
separator
echo "=== Нагрузка на контейнеры ==="
docker stats --no-stream

# Анализ производительности баз данных
separator
echo "=== Производительность PostgreSQL ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT * FROM pg_stat_activity;"

separator
echo "=== Производительность MariaDB ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW PROCESSLIST;"

separator
echo "=== Производительность Redis ==="
docker exec redis redis-cli INFO stats

# Анализ логов на наличие ошибок
separator
echo "=== Анализ логов на наличие ошибок ==="
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker logs $container --tail 20 2>&1 | grep -i "error\|warning\|critical"
done

separator
echo "Анализ завершен. Проверьте вывод для выявления узких мест системы."
EOF

chmod +x /tmp/identify-bottlenecks.sh

# Создание скрипта для оптимизации после выявления узких мест
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/optimize-performance.sh << 'EOF'
#!/bin/bash

echo "Оптимизация производительности системы на основе анализа..."

# Функция для применения оптимизаций
apply_optimization() {
  local component=$1
  local action=$2
  
  echo "=== Оптимизация компонента: $component ==="
  echo "Действие: $action"
  
  case $component in
    "postgres")
      echo "Оптимизация PostgreSQL..."
      # Параметры оптимизации для PostgreSQL
      docker exec postgres psql -U $POSTGRES_USER -c "VACUUM ANALYZE;"
      docker exec postgres psql -U $POSTGRES_USER -c "
      ALTER SYSTEM SET shared_buffers = '256MB';
      ALTER SYSTEM SET effective_cache_size = '1GB';
      ALTER SYSTEM SET work_mem = '16MB';
      ALTER SYSTEM SET maintenance_work_mem = '128MB';
      ALTER SYSTEM SET max_connections = '100';
      SELECT pg_reload_conf();
      "
      ;;
      
    "mariadb")
      echo "Оптимизация MariaDB..."
      # Оптимизация таблиц
      docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
      SELECT CONCAT('OPTIMIZE TABLE ', table_schema, '.', table_name, ';')
      FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'performance_schema')
      " | grep "OPTIMIZE TABLE" | grep -v "CONCAT" | while read query; do
        docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "$query"
      done
      ;;
      
    "redis")
      echo "Оптимизация Redis..."
      # Настройка параметров Redis
      docker exec redis redis-cli CONFIG SET maxmemory "256mb"
      docker exec redis redis-cli CONFIG SET maxmemory-policy "allkeys-lru"
      ;;
      
    "n8n")
      echo "Оптимизация n8n..."
      # Можно увеличить ресурсы контейнера или настроить кеширование
      ;;
      
    "flowise")
      echo "Оптимизация Flowise..."
      # Можно оптимизировать настройки моделей или кеширование
      ;;
      
    "wordpress")
      echo "Оптимизация WordPress..."
      # Очистка и оптимизация базы данных WordPress
      docker exec wordpress wp cache flush --path=/var/www/html 2>/dev/null || echo "WP-CLI не установлен"
      docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "
      DELETE FROM wp_options WHERE option_name LIKE '%transient%' AND option_name != '_transient_doing_cron';
      OPTIMIZE TABLE wp_options;
      "
      ;;
      
    "qdrant")
      echo "Оптимизация Qdrant..."
      # Можно настроить параметры индексов или управление памятью
      ;;
      
    *)
      echo "Неизвестный компонент: $component"
      ;;
  esac
  
  echo "Оптимизация компонента $component завершена"
}

# Применение оптимизаций к разным компонентам
apply_optimization "postgres" "Оптимизация настроек и очистка"
apply_optimization "mariadb" "Оптимизация таблиц"
apply_optimization "redis" "Настройка управления памятью"
apply_optimization "wordpress" "Очистка временных данных"

echo "Применение общесистемных оптимизаций..."

# Очистка неиспользуемых Docker ресурсов
docker system prune -f

# Сброс кеша файловой системы
echo 3 > /proc/sys/vm/drop_caches

echo "Оптимизация производительности системы завершена"
EOF

chmod +x /tmp/optimize-performance.sh
```

#### 9.5.2. Анализ узких мест системы

**Типичные узкие места и способы их устранения:**

1. **Высокая нагрузка на CPU:**
   - Оптимизируйте запросы к базам данных
   - Улучшите алгоритмы обработки данных
   - Рассмотрите возможность горизонтального масштабирования
   - Используйте кеширование для уменьшения вычислений

2. **Проблемы с памятью:**
   - Настройте ограничения памяти для контейнеров
   - Оптимизируйте работу с большими объектами в памяти
   - Внедрите механизмы очистки кеша при достижении пороговых значений
   - Мониторьте утечки памяти и устраняйте их

3. **Узкие места диска и I/O:**
   - Используйте более быстрые носители (SSD вместо HDD)
   - Оптимизируйте запросы к базе данных для уменьшения сканирования диска
   - Настройте правильные индексы для ускорения поиска
   - Уменьшите количество операций журналирования

4. **Проблемы сети:**
   - Оптимизируйте размер передаваемых данных
   - Используйте сжатие трафика
   - Внедрите кеширование для уменьшения сетевых запросов
   - Мониторьте и оптимизируйте сетевую маршрутизацию

5. **Проблемы баз данных:**
   - Оптимизируйте схему и индексы
   - Настройте пулы соединений
   - Регулярно выполняйте обслуживание (VACUUM, OPTIMIZE)
   - Масштабируйте базы данных по необходимости
