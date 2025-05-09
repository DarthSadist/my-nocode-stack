# Руководство по нагрузочному тестированию стека (Часть 4)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

### 9.4. Нагрузочное тестирование систем мониторинга

Мониторинг является важной частью инфраструктуры, однако сами инструменты мониторинга могут стать узким местом при высоких нагрузках на систему. Важно убедиться, что инструменты мониторинга не создают дополнительной нагрузки и могут эффективно функционировать при высокой интенсивности событий.

#### 9.4.1. Тестирование Netdata под нагрузкой

```bash
#!/bin/bash
# Скрипт для тестирования Netdata под нагрузкой
# Сохраните как ~/my-nocode-stack/test-scripts/netdata-load-test.sh

echo "Проверка Netdata под нагрузкой..."

# Подготовка к тестированию
CONTAINER_NAME="netdata"
NETDATA_URL="https://netdata.example.com"
TEST_DURATION=300 # 5 минут
CONCURRENT_USERS=50

echo "Проверка доступности Netdata..."
curl -s -k -I "$NETDATA_URL" | head -n1
if [ $? -ne 0 ]; then
  echo "Netdata недоступен. Проверьте URL и состояние контейнера."
  exit 1
fi

echo "Проверка состояния контейнера Netdata..."
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
if [ "$CONTAINER_STATUS" != "running" ]; then
  echo "Контейнер Netdata не запущен или не существует."
  exit 1
fi

echo "Начало тестирования производительности Netdata..."

# Проверка использования ресурсов перед тестированием
echo "Использование ресурсов перед тестированием:"
docker stats --no-stream "$CONTAINER_NAME"

# Создание временного файла для URLs API Netdata
TEMP_URL_FILE=$(mktemp)
cat > "$TEMP_URL_FILE" << EOF
$NETDATA_URL/api/v1/info
$NETDATA_URL/api/v1/alarms
$NETDATA_URL/api/v1/charts
$NETDATA_URL/api/v1/chart?chart=system.cpu
$NETDATA_URL/api/v1/chart?chart=system.ram
$NETDATA_URL/api/v1/chart?chart=system.io
$NETDATA_URL/api/v1/chart?chart=system.net
EOF

echo "Запуск нагрузочного теста на Netdata..."
echo "Параметры: $CONCURRENT_USERS одновременных пользователей, продолжительность $TEST_DURATION секунд"

# Инструмент для нагрузочного тестирования (требуется установка ab или siege)
if command -v ab &> /dev/null; then
  # Нагрузочное тестирование с использованием Apache Benchmark
  for url in $(cat "$TEMP_URL_FILE"); do
    echo "Тестирование $url..."
    ab -c $CONCURRENT_USERS -t $TEST_DURATION -k -H "Accept-Encoding: gzip, deflate" "$url"
    sleep 2
  done
elif command -v siege &> /dev/null; then
  # Нагрузочное тестирование с использованием Siege
  siege -c $CONCURRENT_USERS -t ${TEST_DURATION}s -f "$TEMP_URL_FILE" -v
else
  echo "Для нагрузочного тестирования требуется установить 'ab' (Apache Benchmark) или 'siege'."
  echo "Установите один из них с помощью менеджера пакетов вашей системы."
  exit 1
fi

# Проверка использования ресурсов после тестирования
echo "Использование ресурсов после тестирования:"
docker stats --no-stream "$CONTAINER_NAME"

# Проверка логов на наличие ошибок
echo "Анализ логов Netdata на наличие ошибок..."
docker logs --tail 100 "$CONTAINER_NAME" | grep -i "error\|warning"

echo "Проверка времени отклика после нагрузки..."
time curl -s -k "$NETDATA_URL/api/v1/info" > /dev/null

# Очистка
rm "$TEMP_URL_FILE"

echo "Тестирование Netdata под нагрузкой завершено."
```

#### 9.4.2. Мониторинг производительности под нагрузкой

```bash
#!/bin/bash
# Скрипт для мониторинга производительности под нагрузкой
# Сохраните как ~/my-nocode-stack/test-scripts/monitoring-performance-test.sh

echo "Тестирование производительности мониторинга под нагрузкой..."

# Настройки
TEST_DURATION=600 # 10 минут
LOG_FILE="/tmp/monitoring-performance-test.log"
STATS_INTERVAL=15 # интервал сбора статистики в секундах

echo "Начало тестирования: $(date)" > "$LOG_FILE"
echo "Продолжительность: $TEST_DURATION секунд" >> "$LOG_FILE"
echo "-----------------------------------" >> "$LOG_FILE"

# Функция для сбора статистики использования ресурсов
collect_stats() {
  echo "Статистика использования ресурсов контейнерами: $(date)" >> "$LOG_FILE"
  docker stats --no-stream >> "$LOG_FILE"
  echo "-----------------------------------" >> "$LOG_FILE"
  
  echo "Статистика системы:" >> "$LOG_FILE"
  top -b -n 1 | head -n 20 >> "$LOG_FILE"
  echo "-----------------------------------" >> "$LOG_FILE"
  
  echo "Использование дисков:" >> "$LOG_FILE"
  df -h >> "$LOG_FILE"
  echo "-----------------------------------" >> "$LOG_FILE"
  
  echo "Статистика сети:" >> "$LOG_FILE"
  netstat -an | grep -c ESTABLISHED >> "$LOG_FILE"
  echo "-----------------------------------" >> "$LOG_FILE"
}

# Функция для генерации нагрузки
generate_load() {
  local target_url="$1"
  local requests="$2"
  local concurrency="$3"
  
  if command -v ab &> /dev/null; then
    ab -n "$requests" -c "$concurrency" -k "$target_url" >> "$LOG_FILE" 2>&1
  else
    echo "Apache Benchmark (ab) не установлен. Невозможно генерировать нагрузку." >> "$LOG_FILE"
  fi
}

# Запуск сбора статистики в фоновом режиме
START_TIME=$(date +%s)
END_TIME=$((START_TIME + TEST_DURATION))

echo "Запуск сбора статистики в фоновом режиме..."

while [ $(date +%s) -lt $END_TIME ]; do
  collect_stats
  sleep $STATS_INTERVAL
done &
STATS_PID=$!

# Генерация нагрузки на систему
echo "Генерация нагрузки на систему..."

# Нагрузка на Netdata
echo "Нагрузка на Netdata..." >> "$LOG_FILE"
generate_load "https://netdata.example.com/api/v1/charts" 5000 20

# Нагрузка на другие сервисы для тестирования сбора метрик
echo "Нагрузка на WordPress..." >> "$LOG_FILE"
generate_load "https://wordpress.example.com/" 3000 15

echo "Нагрузка на N8N..." >> "$LOG_FILE"
generate_load "https://n8n.example.com/" 2000 10

# Дождемся завершения всех фоновых процессов
echo "Ожидание завершения тестирования..."
wait $STATS_PID

echo "Тестирование завершено. Результаты сохранены в $LOG_FILE"
echo "Анализ производительности мониторинга:"
echo "1. Проверьте потребление ресурсов Netdata во время нагрузки"
echo "2. Оцените влияние мониторинга на производительность других сервисов"
echo "3. Проверьте точность собранных метрик во время нагрузки"
```

#### 9.4.3. Оптимизация настроек мониторинга

Для обеспечения эффективной работы мониторинга под нагрузкой, важно оптимизировать его настройки:

```bash
#!/bin/bash
# Скрипт для оптимизации настроек мониторинга
# Сохраните как ~/my-nocode-stack/test-scripts/optimize-monitoring.sh

echo "Оптимизация настроек мониторинга для высоких нагрузок..."

# Создание резервной копии текущих конфигураций
echo "Создание резервных копий текущих конфигураций..."
BACKUP_DIR="/tmp/monitoring-configs-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Копирование и оптимизация конфигурации Netdata
NETDATA_CONFIG_PATH="./compose/netdata/netdata.conf"
if [ -f "$NETDATA_CONFIG_PATH" ]; then
  cp "$NETDATA_CONFIG_PATH" "$BACKUP_DIR/"
  
  echo "Оптимизация настроек Netdata..."
  # Если файл не существует или не содержит нужные настройки, создаем его
  if [ ! -f "$NETDATA_CONFIG_PATH" ] || ! grep -q "\[global\]" "$NETDATA_CONFIG_PATH"; then
    mkdir -p $(dirname "$NETDATA_CONFIG_PATH")
    cat > "$NETDATA_CONFIG_PATH" << EOF
[global]
    update every = 5
    memory mode = ram
    history = 3600
    cleanup obsolete charts = yes
    cleanup orphan hosts = yes

[web]
    disconnect idle clients after seconds = 60
    timeout for first request = 60
    respect do not track policy = yes
    allow connections from = localhost 10.* 192.168.* 172.* 127.*

[plugins]
    go.d = yes
    python.d = yes
    charts.d = yes
    node.d = yes
    proc = yes
    diskspace = yes
    cgroups = yes
    tc = no
    idlejitter = no
    enable running new plugins = no
EOF
    echo "Создана оптимизированная конфигурация Netdata."
  else
    # Если файл существует, вносим изменения
    sed -i 's/update every = 1/update every = 5/g' "$NETDATA_CONFIG_PATH"
    sed -i 's/history = 86400/history = 3600/g' "$NETDATA_CONFIG_PATH"
    
    # Добавление или обновление секции web, если она не существует
    if ! grep -q "\[web\]" "$NETDATA_CONFIG_PATH"; then
      echo -e "\n[web]\n    disconnect idle clients after seconds = 60\n    timeout for first request = 60" >> "$NETDATA_CONFIG_PATH"
    else
      sed -i '/\[web\]/,/\[/ s/disconnect idle clients after seconds = .*/disconnect idle clients after seconds = 60/' "$NETDATA_CONFIG_PATH"
      sed -i '/\[web\]/,/\[/ s/timeout for first request = .*/timeout for first request = 60/' "$NETDATA_CONFIG_PATH"
    fi
    
    echo "Обновлена существующая конфигурация Netdata."
  fi
else
  echo "Файл конфигурации Netdata не найден. Проверьте путь: $NETDATA_CONFIG_PATH"
fi

# Проверка и оптимизация ресурсов Docker
echo "Оптимизация ресурсов Docker для мониторинга..."
DOCKER_COMPOSE_PATH="./docker-compose.yml"

if [ -f "$DOCKER_COMPOSE_PATH" ]; then
  cp "$DOCKER_COMPOSE_PATH" "$BACKUP_DIR/"
  
  # Проверка и обновление лимитов ресурсов для Netdata
  if grep -q "netdata:" "$DOCKER_COMPOSE_PATH"; then
    # Проверка наличия секции resources у netdata
    if ! grep -A10 "netdata:" "$DOCKER_COMPOSE_PATH" | grep -q "resources:"; then
      # Добавление ограничений ресурсов для Netdata, если их нет
      sed -i '/netdata:/,/^[^ ]/ s/^/    resources:\n      limits:\n        cpus: "0.5"\n        memory: 512M\n      reservations:\n        cpus: "0.1"\n        memory: 128M\n/' "$DOCKER_COMPOSE_PATH"
      echo "Добавлены ограничения ресурсов для Netdata."
    else
      echo "Конфигурация ресурсов для Netdata уже существует."
    fi
  else
    echo "Сервис Netdata не найден в docker-compose.yml."
  fi
else
  echo "Файл docker-compose.yml не найден. Проверьте путь: $DOCKER_COMPOSE_PATH"
fi

echo "Оптимизация системных настроек для мониторинга..."
# Настройка sysctl для улучшения производительности сети
cat > /tmp/monitoring-sysctl.conf << EOF
# Увеличение лимитов для сетевых соединений
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_tw_reuse = 1

# Увеличение размера буферов для сетевых соединений
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

echo "Системные настройки для мониторинга подготовлены в /tmp/monitoring-sysctl.conf"
echo "Чтобы применить их, выполните: sudo sysctl -p /tmp/monitoring-sysctl.conf"

echo "Оптимизация настроек мониторинга завершена."
echo "Резервные копии сохранены в: $BACKUP_DIR"
echo "Перезапустите сервисы для применения изменений: docker-compose down && docker-compose up -d"
```

Эти оптимизации помогут обеспечить стабильную работу систем мониторинга даже при высоких нагрузках, не создавая дополнительной нагрузки на всю инфраструктуру.

### 9.4.4. Анализ влияния мониторинга на производительность

Системы мониторинга должны собирать данные, не оказывая значительного влияния на производительность основных сервисов. Важно провести анализ для определения оптимального баланса между детальностью мониторинга и его влиянием на систему:

**Ключевые аспекты для анализа:**

1. **Влияние частоты сбора метрик:**
   - Высокая частота (каждую секунду) — больше деталей, но выше нагрузка
   - Средняя частота (5-15 секунд) — оптимальный баланс для большинства систем
   - Низкая частота (30+ секунд) — минимальное воздействие, но потеря детализации

2. **Объем собираемых метрик:**
   - Необходимо определить, какие метрики действительно важны
   - Отключить сбор неиспользуемых или избыточных метрик
   - Настроить различные интервалы для разных типов метрик

3. **Хранение и ротация данных:**
   - Хранение в RAM для наиболее активно используемых данных
   - Использование эффективных форматов хранения
   - Настройка политик ротации данных для экономии ресурсов

**Рекомендуемые настройки в зависимости от размера инфраструктуры:**

| Размер системы | Частота сбора | Хранение истории | Рекомендуемые ресурсы |
|----------------|---------------|------------------|------------------------|
| Малая (5-10 контейнеров) | 1 секунда | 24 часа | CPU: 0.5, RAM: 512MB |
| Средняя (10-50 контейнеров) | 5 секунд | 12 часов | CPU: 1, RAM: 1GB |
| Большая (50+ контейнеров) | 10 секунд | 6 часов | CPU: 2, RAM: 2-4GB |

Эти рекомендации помогут настроить мониторинг таким образом, чтобы он предоставлял необходимую информацию, не создавая при этом чрезмерной нагрузки на инфраструктуру.
