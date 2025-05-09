# Руководство по нагрузочному тестированию стека (Часть 6)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

### 9.6. Рекомендации по нагрузочному тестированию

При проведении нагрузочного тестирования стека важно придерживаться систематического подхода, который позволит получить наиболее полную и достоверную информацию о производительности системы.

#### 7.6.1. Поэтапный подход к нагрузочному тестированию

1. **Начинайте с низкой нагрузки и постепенно увеличивайте её:**
   - Определите базовый уровень производительности при минимальной нагрузке
   - Постепенно увеличивайте нагрузку, чтобы найти пороговые значения
   - Фиксируйте результаты на каждом этапе для построения кривой производительности
   - Анализируйте, при какой нагрузке начинает проявляться деградация производительности

2. **Тестируйте компоненты по отдельности перед комплексным тестированием:**
   - Начните с тестирования каждого компонента изолированно
   - Выявите индивидуальные характеристики производительности каждого сервиса
   - Определите максимальную пропускную способность отдельных компонентов
   - Используйте эти данные как основу для проектирования комплексных тестов

3. **Имитируйте реальные сценарии использования:**
   - Создавайте тесты, имитирующие реальные пользовательские сценарии
   - Учитывайте типичные паттерны использования в вашей предметной области
   - Тестируйте наиболее критичные и часто используемые функции
   - Включайте в тесты случайные вариации для приближения к реальным условиям

```bash
# Скрипт для имитации реальных пользовательских сценариев
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/real-world-scenarios.sh << 'EOF'
#!/bin/bash

echo "Тестирование реальных пользовательских сценариев..."

# Сценарий 1: Пользователь просматривает WordPress и выполняет поиск
echo "=== Сценарий 1: Просмотр WordPress и поиск ==="
{
  # Посещение главной страницы
  curl -s -o /dev/null -w "Главная страница: %{time_total} сек\n" https://wordpress.yourdomain.com/
  sleep 2
  
  # Просмотр нескольких страниц
  for i in {1..3}; do
    curl -s -o /dev/null -w "Просмотр страницы $i: %{time_total} сек\n" https://wordpress.yourdomain.com/?p=$i
    sleep 1
  done
  
  # Выполнение поиска
  curl -s -o /dev/null -w "Поиск: %{time_total} сек\n" "https://wordpress.yourdomain.com/?s=тест"
} &

# Сценарий 2: Обработка данных через n8n и Flowise
echo "=== Сценарий 2: Обработка данных через n8n и Flowise ==="
{
  # Отправка данных в webhook n8n
  curl -s -X POST "https://n8n.yourdomain.com/webhook/process-data" \
    -H "Content-Type: application/json" \
    -d '{"data": "Тестовые данные для обработки", "timestamp": "'$(date -Iseconds)'"}' \
    -o ~/my-nocode-stack/test-scripts/n8n-response.json
  
  # Получение ID чатфлоу Flowise
  FLOW_ID=$(curl -s https://flowise.yourdomain.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')
  
  if [ -n "$FLOW_ID" ]; then
    # Отправка данных в Flowise для анализа
    curl -s -X POST "https://flowise.yourdomain.com/api/v1/prediction/$FLOW_ID" \
      -H "Content-Type: application/json" \
      -d '{
        "question": "Проанализируй следующие данные: Продажи выросли на 15% в первом квартале",
        "overrideConfig": {
          "sessionId": "real-world-test-session"
        }
      }' \
      -o ~/my-nocode-stack/test-scripts/flowise-response.json
  fi
} &

# Сценарий 3: Комплексный сценарий с использованием нескольких компонентов
echo "=== Сценарий 3: Комплексный сценарий с несколькими компонентами ==="
{
  # Создание поста в WordPress
  TOKEN=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/jwt-auth/v1/token \
    --data "username=admin&password=your_password" | grep -o '"token":"[^"]*' | sed 's/"token":"//')
  
  if [ -n "$TOKEN" ]; then
    # Создание тестового поста
    POST_RESPONSE=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/wp/v2/posts \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "title": "Тестовый пост для реального сценария",
        "content": "Это тестовый пост, созданный в рамках тестирования реальных пользовательских сценариев",
        "status": "publish"
      }')
    
    POST_ID=$(echo $POST_RESPONSE | grep -o '"id":[0-9]*' | sed 's/"id"://')
    
    if [ -n "$POST_ID" ]; then
      echo "Создан тестовый пост с ID: $POST_ID"
      
      # Инициация webhook в n8n для обработки нового поста
      curl -s -X POST "https://n8n.yourdomain.com/webhook/new-post" \
        -H "Content-Type: application/json" \
        -d '{"post_id": "'$POST_ID'", "action": "process_new_post"}'
      
      # Имитация поиска похожего контента в Qdrant
      curl -s -X POST "http://localhost:6333/collections/content_vectors/points/search" \
        -H "Content-Type: application/json" \
        -d '{
          "filter": {
            "must": [
              {
                "key": "content_type",
                "match": {
                  "value": "post"
                }
              }
            ]
          },
          "limit": 5
        }' \
        -o ~/my-nocode-stack/test-scripts/qdrant-search-results.json
    fi
  fi
} &

wait
echo "Тестирование реальных пользовательских сценариев завершено"
EOF

chmod +x ~/my-nocode-stack/test-scripts/real-world-scenarios.sh
```

#### 7.6.2. Мониторинг ресурсов во время тестирования

Эффективный мониторинг ресурсов критически важен для понимания поведения системы под нагрузкой.

```bash
# Скрипт для мониторинга ресурсов во время нагрузочного тестирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/monitor-resources-during-test.sh << 'EOF'
#!/bin/bash

echo "Мониторинг ресурсов во время нагрузочного тестирования..."

# Создание директории для результатов мониторинга
mkdir -p ~/my-nocode-stack/test-scripts/load-test-monitoring

# Функция для сохранения снапшота использования ресурсов
capture_resources() {
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  
  # Использование CPU
  top -b -n 1 > "~/my-nocode-stack/test-scripts/load-test-monitoring/top_$timestamp.txt"
  
  # Использование памяти
  free -h > "~/my-nocode-stack/test-scripts/load-test-monitoring/memory_$timestamp.txt"
  
  # Использование диска
  df -h > "~/my-nocode-stack/test-scripts/load-test-monitoring/disk_$timestamp.txt"
  
  # Статистика контейнеров
  docker stats --no-stream > "~/my-nocode-stack/test-scripts/load-test-monitoring/containers_$timestamp.txt"
  
  # Сетевые подключения
  netstat -tunapl | grep ESTABLISHED | wc -l > "~/my-nocode-stack/test-scripts/load-test-monitoring/connections_$timestamp.txt"
  
  # Нагрузка на базы данных
  docker exec postgres psql -U $POSTGRES_USER -c "SELECT count(*) FROM pg_stat_activity;" > "~/my-nocode-stack/test-scripts/load-test-monitoring/postgres_connections_$timestamp.txt" 2>/dev/null
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW STATUS LIKE 'Threads_connected';" > "~/my-nocode-stack/test-scripts/load-test-monitoring/mariadb_connections_$timestamp.txt" 2>/dev/null
  docker exec redis redis-cli INFO clients | grep connected_clients > "~/my-nocode-stack/test-scripts/load-test-monitoring/redis_connections_$timestamp.txt"
}

# Запуск мониторинга с интервалом 5 секунд
echo "Запуск непрерывного мониторинга ресурсов (Ctrl+C для остановки)..."
while true; do
  capture_resources
  sleep 5
done
EOF

chmod +x ~/my-nocode-stack/test-scripts/monitor-resources-during-test.sh
```

**Что нужно отслеживать во время тестирования:**
- **CPU**: Общая загрузка и загрузка по процессам
- **Память**: Использование оперативной памяти и файла подкачки
- **Диск и I/O**: Скорость чтения/записи и количество операций
- **Сеть**: Пропускная способность, задержки и количество соединений
- **Метрики специфичные для компонентов**: Счетчики запросов, время отклика, количество ошибок

#### 7.6.3. Анализ результатов и оптимизация

Правильный анализ результатов тестирования позволяет выявить проблемы и определить направления оптимизации.

```bash
# Скрипт для анализа результатов нагрузочного тестирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/analyze-load-test-results.sh << 'EOF'
#!/bin/bash

echo "Анализ результатов нагрузочного тестирования..."

# Проверка наличия директории с результатами
if [ ! -d "~/my-nocode-stack/test-scripts/load-test-monitoring" ]; then
  echo "Ошибка: Директория с результатами мониторинга не найдена."
  exit 1
fi

# Анализ использования CPU
echo "=== Анализ использования CPU ==="
echo "Средняя загрузка CPU:"
grep "load average" ~/my-nocode-stack/test-scripts/load-test-monitoring/top_*.txt | awk '{sum+=$12} END {print sum/NR}'

echo "Наибольшие потребители CPU:"
cat ~/my-nocode-stack/test-scripts/load-test-monitoring/top_*.txt | grep -v "PID" | awk '{print $9, $12}' | sort -nr | head -10

# Анализ использования памяти
echo -e "\n=== Анализ использования памяти ==="
echo "Среднее использование памяти:"
grep "Mem:" ~/my-nocode-stack/test-scripts/load-test-monitoring/memory_*.txt | awk '{used+=$3; total+=$2} END {print (used/NR)" из "total/NR" MB ("used/total*100"%)"}'

# Анализ использования диска
echo -e "\n=== Анализ использования диска ==="
echo "Изменение свободного места на диске:"
FIRST_FILE=$(ls -1 ~/my-nocode-stack/test-scripts/load-test-monitoring/disk_*.txt | head -1)
LAST_FILE=$(ls -1 ~/my-nocode-stack/test-scripts/load-test-monitoring/disk_*.txt | tail -1)
echo "Начало: $(grep "/dev/sda" $FIRST_FILE | awk '{print $4}')"
echo "Конец: $(grep "/dev/sda" $LAST_FILE | awk '{print $4}')"

# Анализ контейнеров
echo -e "\n=== Анализ контейнеров ==="
echo "Среднее использование ресурсов контейнерами:"
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  grep "$container" ~/my-nocode-stack/test-scripts/load-test-monitoring/containers_*.txt | awk '{cpu+=$3; mem+=$7} END {print "CPU: "cpu/NR"%, Память: "mem/NR"%"}'
done

# Анализ подключений к базам данных
echo -e "\n=== Анализ подключений к базам данных ==="
echo "PostgreSQL - максимальное количество соединений:"
cat ~/my-nocode-stack/test-scripts/load-test-monitoring/postgres_connections_*.txt | grep -o "[0-9]*" | sort -n | tail -1

echo "MariaDB - максимальное количество соединений:"
cat ~/my-nocode-stack/test-scripts/load-test-monitoring/mariadb_connections_*.txt | grep -o "[0-9]*" | sort -n | tail -1

echo "Redis - максимальное количество соединений:"
cat ~/my-nocode-stack/test-scripts/load-test-monitoring/redis_connections_*.txt | grep -o "[0-9]*" | sort -n | tail -1

# Формирование рекомендаций
echo -e "\n=== Рекомендации по оптимизации ==="
# CPU
CPU_AVG=$(grep "load average" ~/my-nocode-stack/test-scripts/load-test-monitoring/top_*.txt | awk '{sum+=$12} END {print sum/NR}')
if (( $(echo "$CPU_AVG > 0.7" | bc -l) )); then
  echo "- Высокая загрузка CPU. Рекомендуется оптимизировать код или увеличить ресурсы CPU."
fi

# Память
MEM_PCT=$(grep "Mem:" ~/my-nocode-stack/test-scripts/load-test-monitoring/memory_*.txt | awk '{used+=$3; total+=$2} END {print used/total}')
if (( $(echo "$MEM_PCT > 0.8" | bc -l) )); then
  echo "- Высокое использование памяти. Рекомендуется оптимизировать использование памяти или увеличить объем RAM."
fi

# Диск
DISK_START=$(grep "/dev/sda" $FIRST_FILE | awk '{gsub("%","",$5); print $5}')
DISK_END=$(grep "/dev/sda" $LAST_FILE | awk '{gsub("%","",$5); print $5}')
if (( $(echo "$DISK_END - $DISK_START > 5" | bc -l) )); then
  echo "- Значительное увеличение использования диска. Проверьте логи и временные файлы."
fi

# Контейнеры
grep -r "n8n" ~/my-nocode-stack/test-scripts/load-test-monitoring/containers_*.txt | awk '{cpu+=$3; count+=1} END {if(cpu/count > 70) print "- Высокая загрузка CPU у контейнера n8n. Рассмотрите оптимизацию или масштабирование."}'
grep -r "postgres" ~/my-nocode-stack/test-scripts/load-test-monitoring/containers_*.txt | awk '{cpu+=$3; count+=1} END {if(cpu/count > 70) print "- Высокая загрузка CPU у контейнера postgres. Оптимизируйте запросы или индексы."}'

# Соединения с БД
PG_MAX=$(cat ~/my-nocode-stack/test-scripts/load-test-monitoring/postgres_connections_*.txt | grep -o "[0-9]*" | sort -n | tail -1)
if [ "$PG_MAX" -gt 20 ]; then
  echo "- Большое количество соединений с PostgreSQL ($PG_MAX). Настройте пул соединений."
fi

MARIA_MAX=$(cat ~/my-nocode-stack/test-scripts/load-test-monitoring/mariadb_connections_*.txt | grep -o "[0-9]*" | sort -n | tail -1)
if [ "$MARIA_MAX" -gt 20 ]; then
  echo "- Большое количество соединений с MariaDB ($MARIA_MAX). Настройте пул соединений."
fi

echo "Анализ результатов нагрузочного тестирования завершен"
EOF

chmod +x ~/my-nocode-stack/test-scripts/analyze-load-test-results.sh
```

**Подходы к оптимизации на основе результатов:**

1. **Оптимизация кода и алгоритмов:**
   - Профилирование и оптимизация медленных участков кода
   - Улучшение алгоритмов обработки данных
   - Уменьшение сложности операций

2. **Оптимизация баз данных:**
   - Анализ и оптимизация SQL-запросов
   - Создание эффективных индексов
   - Настройка параметров баз данных под конкретные нагрузки

3. **Кеширование:**
   - Внедрение кеширования часто запрашиваемых данных
   - Использование Redis для хранения кеша
   - Настройка правил инвалидации кеша

4. **Распределение нагрузки:**
   - Горизонтальное масштабирование компонентов с высокой нагрузкой
   - Внедрение балансировщиков нагрузки
   - Распределение операций по времени для снижения пиковых нагрузок

5. **Оптимизация ресурсов:**
   - Настройка выделения ресурсов Docker для каждого контейнера
   - Балансировка ресурсов между компонентами
   - Увеличение ресурсов для критичных сервисов

#### 9.6.4. Регулярность проведения тестирования

Для поддержания высокой производительности системы важно проводить нагрузочное тестирование на регулярной основе.

**Рекомендации по планированию тестирования:**

1. **После каждого значительного обновления:**
   - Тестируйте обновленные компоненты индивидуально
   - Проводите интеграционное тестирование для проверки взаимодействия
   - Сравнивайте результаты с предыдущими версиями

2. **При изменении конфигурации системы:**
   - Проверяйте влияние изменений на производительность
   - Тестируйте различные конфигурации для выбора оптимальной
   - Документируйте влияние параметров на производительность

3. **По регулярному расписанию:**
   - Ежемесячно: базовое нагрузочное тестирование
   - Ежеквартально: полное нагрузочное тестирование всего стека
   - Ежегодно: масштабное стресс-тестирование с имитацией экстремальных нагрузок

```bash
# Скрипт для автоматизации регулярного тестирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/schedule-regular-testing.sh << 'EOF'
#!/bin/bash

# Скрипт для добавления задач регулярного нагрузочного тестирования в crontab

# Функция для добавления задачи в crontab
add_cron_job() {
  local schedule=$1
  local command=$2
  local description=$3
  
  # Проверка наличия задачи
  crontab -l | grep -F "$command" > /dev/null
  if [ $? -eq 0 ]; then
    echo "Задача '$description' уже существует в crontab"
  else
    # Добавление задачи
    (crontab -l 2>/dev/null; echo "# $description"; echo "$schedule $command") | crontab -
    echo "Задача '$description' добавлена в crontab"
  fi
}

echo "Настройка регулярного нагрузочного тестирования..."

# Еженедельное базовое тестирование (каждый понедельник в 1:00)
add_cron_job "0 1 * * 1" "~/my-nocode-stack/test-scripts/full-stack-load-test.sh > ~/my-nocode-stack/test-scripts/weekly-load-test-\$(date +\%Y\%m\%d).log 2>&1" "Еженедельное базовое нагрузочное тестирование"

# Ежемесячное полное тестирование (1-е число каждого месяца в 2:00)
add_cron_job "0 2 1 * *" "~/my-nocode-stack/test-scripts/full-stack-load-test.sh && ~/my-nocode-stack/test-scripts/analyze-load-test-results.sh > ~/my-nocode-stack/test-scripts/monthly-load-test-\$(date +\%Y\%m).log 2>&1" "Ежемесячное полное нагрузочное тестирование"

# Ежеквартальное тестирование с оптимизацией (1-е число каждого квартала в 3:00)
add_cron_job "0 3 1 */3 *" "~/my-nocode-stack/test-scripts/full-stack-load-test.sh && ~/my-nocode-stack/test-scripts/analyze-load-test-results.sh && ~/my-nocode-stack/test-scripts/optimize-performance.sh > ~/my-nocode-stack/test-scripts/quarterly-load-test-\$(date +\%Y\%m).log 2>&1" "Ежеквартальное тестирование с оптимизацией"

echo "Регулярное нагрузочное тестирование настроено"
echo "Просмотр текущих задач crontab:"
crontab -l
EOF

chmod +x /tmp/schedule-regular-testing.sh
```

### 7.7. Заключение по нагрузочному тестированию

Нагрузочное тестирование является критически важным аспектом обеспечения надежности и производительности вашего стека. Систематический подход к тестированию, регулярный мониторинг и своевременная оптимизация позволят поддерживать высокую производительность системы даже при значительном росте нагрузки.

Важно помнить, что нагрузочное тестирование – это непрерывный процесс, а не разовое мероприятие. По мере развития вашей системы, добавления новых функций и компонентов, тестирование должно адаптироваться и охватывать все аспекты работы стека.

Используя созданные инструменты и следуя рекомендациям из этого руководства, вы сможете своевременно выявлять и устранять узкие места в производительности, обеспечивая стабильную работу всех компонентов вашего технологического стека.
