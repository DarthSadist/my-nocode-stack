# Руководство по нагрузочному тестированию стека (Часть 1)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

## 9. Нагрузочное тестирование

Нагрузочное тестирование является критически важным этапом для обеспечения стабильности и производительности всей системы в условиях повышенной нагрузки. Оно позволяет выявить узкие места, определить максимальную пропускную способность и оценить поведение системы при различных уровнях нагрузки.

### 9.1. Подготовка к нагрузочному тестированию

#### 9.1.1. Подготовка тестовой среды

Перед началом нагрузочного тестирования необходимо подготовить тестовую среду:

```bash
# Проверка текущей нагрузки на систему (должна быть минимальной)
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Проверка доступных ресурсов системы
free -h
df -h
cat /proc/cpuinfo | grep processor | wc -l
```

**Что проверять и почему это важно:**
- **Базовая нагрузка системы**: Перед началом тестирования система должна быть в спокойном состоянии с минимальной нагрузкой.
- **Доступная память**: Убедитесь, что имеется достаточно свободной памяти (минимум 50% от общей).
- **Свободное место на диске**: Проверьте, что достаточно места для логов и временных данных (минимум 10-20 ГБ).
- **Доступные ядра процессора**: Проверьте количество доступных процессорных ядер для параллельной обработки.

**Рекомендации по подготовке:**
- Убедитесь, что система находится в стабильном состоянии
- Остановите все несущественные службы
- Создайте снапшоты/резервные копии перед началом тестирования
- Настройте мониторинг ресурсов через Netdata

```bash
# Создание скрипта для подготовки среды к нагрузочному тестированию
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/prepare-load-testing.sh << 'EOF'
#!/bin/bash

echo "Подготовка среды к нагрузочному тестированию..."

# Проверка статуса сервисов
echo "=== Статус сервисов ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Очистка логов для освобождения места
echo -e "\n=== Очистка логов ==="
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "Очистка логов для $container..."
  docker logs $container --tail 1 > /dev/null 2>&1
  docker exec $container sh -c 'if [ -d /var/log ]; then find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true; fi'
done

# Очистка временных файлов
echo -e "\n=== Очистка временных файлов ==="
docker exec wordpress sh -c 'if [ -d /tmp ]; then find /tmp -type f -mtime +1 -delete 2>/dev/null || true; fi'
docker exec n8n sh -c 'if [ -d /tmp ]; then find /tmp -type f -mtime +1 -delete 2>/dev/null || true; fi'

# Перезапуск Netdata для мониторинга
echo -e "\n=== Подготовка Netdata ==="
docker restart netdata
echo "Netdata перезапущен для мониторинга нагрузочного тестирования"

# Текущие ресурсы
echo -e "\n=== Текущее использование ресурсов ==="
free -h
df -h
echo "Процессоры: $(cat /proc/cpuinfo | grep processor | wc -l)"
docker stats --no-stream

echo -e "\nСреда подготовлена к нагрузочному тестированию!"
EOF

chmod +x /tmp/prepare-load-testing.sh
```

#### 9.1.2. Установка инструментов для нагрузочного тестирования

Для проведения нагрузочного тестирования потребуются специальные инструменты:

```bash
# Установка ab (Apache Benchmark)
apt-get update && apt-get install -y apache2-utils

# Установка wrk - современного инструмента для HTTP-бенчмаркинга
apt-get install -y build-essential libssl-dev git
git clone https://github.com/wg/wrk.git
cd wrk
make
mv wrk /usr/local/bin

# Установка hey - инструмента для нагрузочного тестирования от Google
wget -q https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 -O /usr/local/bin/hey
chmod +x /usr/local/bin/hey

# Установка vegeta - инструмента для нагрузочного тестирования HTTP-сервисов
wget -q https://github.com/tsenart/vegeta/releases/download/v12.8.4/vegeta_12.8.4_linux_amd64.tar.gz -O vegeta.tar.gz
tar -xzf vegeta.tar.gz vegeta
mv vegeta /usr/local/bin/
rm vegeta.tar.gz
```

**Сравнение инструментов нагрузочного тестирования:**
- **ab (Apache Benchmark)**: Простой и надежный инструмент для базовых тестов.
- **wrk**: Более современный и производительный инструмент с поддержкой Lua-скриптов.
- **hey**: Простой и понятный инструмент от Google с хорошей статистикой.
- **vegeta**: Мощный инструмент для постоянной скорости запросов и подробной статистики.

```bash
# Создание скрипта для проверки установленных инструментов
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/check-load-testing-tools.sh << 'EOF'
#!/bin/bash

echo "Проверка инструментов для нагрузочного тестирования..."

# Проверка Apache Benchmark
if command -v ab > /dev/null; then
  echo "Apache Benchmark (ab) установлен: $(ab -V | head -1)"
else
  echo "Apache Benchmark (ab) не установлен!"
fi

# Проверка wrk
if command -v wrk > /dev/null; then
  echo "wrk установлен: $(wrk -v 2>&1 | head -1)"
else
  echo "wrk не установлен!"
fi

# Проверка hey
if command -v hey > /dev/null; then
  echo "hey установлен"
else
  echo "hey не установлен!"
fi

# Проверка vegeta
if command -v vegeta > /dev/null; then
  echo "vegeta установлен: $(vegeta -version)"
else
  echo "vegeta не установлен!"
fi

echo "Проверка завершена!"
EOF

chmod +x /tmp/check-load-testing-tools.sh
```

### 9.2. Тестирование веб-интерфейсов и API

#### 9.2.1. Тестирование n8n

```bash
# Базовый тест производительности n8n
ab -n 1000 -c 50 -k -H "Accept-Encoding: gzip, deflate" https://n8n.yourdomain.com/

# Развернутый тест с различным числом параллельных соединений
for c in 10 25 50 100; do
  echo "--- Тестирование n8n с $c параллельными соединениями ---"
  wrk -t4 -c$c -d30s https://n8n.yourdomain.com/
  sleep 10
done

# Создание скрипта для регулярного тестирования n8n
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/n8n-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование n8n..."

# Функция для проведения теста с разными инструментами
test_n8n() {
  local url="https://n8n.yourdomain.com"
  local endpoint=$1

  echo "=== Тестирование $url$endpoint ==="
  
  # Тест с Apache Benchmark
  echo "Тест с Apache Benchmark (ab):"
  ab -n 500 -c 50 -k -H "Accept-Encoding: gzip, deflate" "$url$endpoint"
  
  # Тест с wrk
  echo -e "\nТест с wrk:"
  wrk -t2 -c50 -d20s "$url$endpoint"
  
  # Тест с hey
  echo -e "\nТест с hey:"
  hey -n 500 -c 50 -m GET "$url$endpoint"
  
  echo -e "\nТестирование $url$endpoint завершено\n"
}

# Тестирование разных эндпоинтов n8n
test_n8n "/"
test_n8n "/workflow"
test_n8n "/healthz"

# Тестирование аутентификации (если применимо)
if [[ -n "$N8N_DEFAULT_USER_EMAIL" && -n "$N8N_DEFAULT_USER_PASSWORD" ]]; then
  echo "=== Тестирование аутентификации ==="
  
  # Создание файла с данными для POST-запроса
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/n8n-auth-data.json << EOT
{
  "email": "$N8N_DEFAULT_USER_EMAIL",
  "password": "$N8N_DEFAULT_USER_PASSWORD"
}
EOT
  
  # Тест аутентификации
  hey -n 100 -c 10 -m POST \
    -H "Content-Type: application/json" \
    -D /tmp/n8n-auth-data.json \
    "https://n8n.yourdomain.com/rest/login"
  
  rm /tmp/n8n-auth-data.json
fi

echo "Нагрузочное тестирование n8n завершено!"
EOF

chmod +x /tmp/n8n-load-test.sh
```

**Что анализировать:**
- **Запросов в секунду (RPS)**: Определяет пропускную способность системы.
- **Время отклика**: Среднее, медианное, 95 и 99 перцентили.
- **Стабильность под нагрузкой**: Отсутствие ошибок и сбоев.
- **Использование ресурсов**: Мониторинг CPU, памяти, дисковых операций и сети.

**Рекомендации по оптимизации n8n:**
- Увеличьте выделенные ресурсы для контейнера n8n в docker-compose.yml
- Настройте кеширование для часто используемых данных
- Оптимизируйте потоки, избегая ресурсоемких операций
- Рассмотрите горизонтальное масштабирование с балансировкой нагрузки

#### 9.2.2. Тестирование Flowise

```bash
# Базовый тест доступности Flowise
ab -n 500 -c 25 -k -H "Accept-Encoding: gzip, deflate" https://flowise.yourdomain.com/

# Тест API-эндпоинтов Flowise
hey -n 200 -c 20 -m GET https://flowise.yourdomain.com/api/v1/health

# Создание скрипта для регулярного тестирования Flowise
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование Flowise..."

# Функция для проведения теста с разными инструментами
test_flowise() {
  local url="https://flowise.yourdomain.com"
  local endpoint=$1
  local method=${2:-GET}

  echo "=== Тестирование $method $url$endpoint ==="
  
  # Тест с wrk
  if [ "$method" = "GET" ]; then
    wrk -t2 -c30 -d20s "$url$endpoint"
  fi
  
  # Тест с hey
  hey -n 300 -c 30 -m $method "$url$endpoint"
  
  echo -e "\nТестирование $method $url$endpoint завершено\n"
}

# Тестирование разных эндпоинтов Flowise
test_flowise "/"
test_flowise "/api/v1/health"
test_flowise "/api/v1/components"
test_flowise "/api/v1/version"

# Получение ID чатфлоу для тестирования предсказаний
FLOW_ID=$(curl -s https://flowise.yourdomain.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -n "$FLOW_ID" ]; then
  echo "=== Тестирование endpoint предсказаний ==="
  
  # Создание файла с данными для POST-запроса
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-predict-data.json << EOT
{
  "question": "Тестовый запрос для нагрузочного тестирования",
  "overrideConfig": {
    "sessionId": "load-test-session"
  }
}
EOT
  
  # Тестирование POST-запросов к API предсказаний
  hey -n 50 -c 5 -m POST \
    -H "Content-Type: application/json" \
    -D /tmp/flowise-predict-data.json \
    "https://flowise.yourdomain.com/api/v1/prediction/$FLOW_ID"
  
  rm /tmp/flowise-predict-data.json
else
  echo "Не удалось получить ID чатфлоу для тестирования"
fi

echo "Нагрузочное тестирование Flowise завершено!"
EOF

chmod +x /tmp/flowise-load-test.sh
```

**Рекомендации по оптимизации Flowise:**
- Настройте кеширование ответов для часто задаваемых вопросов
- Оптимизируйте модели, используя более легкие версии, где возможно
- Увеличьте таймауты для длительных операций
- Мониторьте использование памяти, особенно при загрузке больших моделей
