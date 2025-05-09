# Расширенное руководство по тестированию n8n

## 4.1. Тестирование n8n

n8n - это мощный инструмент автоматизации рабочих процессов, и его правильная работа критически важна для всей экосистемы вашего стека. Детальное тестирование позволит убедиться, что все компоненты n8n функционируют корректно и интеграции с другими сервисами работают стабильно.

### 4.1.1. Проверка доступности n8n

```bash
# Проверка доступности по HTTP
curl -k -I https://n8n.yourdomain.com
```

**Что проверяем и почему это важно:**
- **Код ответа HTTP**: Должен быть 200 OK или 302 (перенаправление на страницу входа). Любой другой код (особенно 5xx) указывает на проблемы с сервисом.
- **Заголовки безопасности**: Проверяем наличие заголовков безопасности, таких как CORS, Content-Security-Policy и т.д.
- **Перенаправления**: Убедитесь, что HTTP-запросы корректно перенаправляются на HTTPS.

**Ожидаемый результат:**
```
HTTP/2 200 
server: Caddy
content-type: text/html; charset=utf-8
date: Fri, 09 May 2025 02:05:00 GMT
strict-transport-security: max-age=31536000; includeSubDomains
x-powered-by: n8n
```

**Проверка веб-интерфейса через браузер:**
1. Откройте https://n8n.yourdomain.com в браузере
2. Убедитесь, что страница входа загружается корректно
3. Проверьте, что все ресурсы страницы (CSS, JavaScript) загружаются без ошибок
4. Убедитесь в отсутствии ошибок в консоли браузера (F12 -> Console)

**Возможные проблемы и их решения:**
- **503 Service Unavailable**: Контейнер n8n может быть не запущен или перегружен. Проверьте логи и ресурсы.
- **502 Bad Gateway**: Проблема с Caddy. Проверьте конфигурацию Caddy и перезапустите его.
- **Timeout**: Сеть или сервер перегружены. Проверьте использование ресурсов и сетевые настройки.

### 4.1.2. Проверка логов n8n

```bash
# Проверка логов n8n
docker logs n8n
```

**Что искать в логах:**
- **Информация о запуске**: Успешная инициализация всех компонентов n8n
- **Подключение к базе данных**: Успешное соединение с PostgreSQL
- **Ошибки и предупреждения**: Обращайте внимание на записи с уровнем ERROR или WARN
- **Webhook registrations**: Проверьте успешную регистрацию webhooks
- **Активация лицензии**: Если используется платная версия, проверьте статус лицензии

**Полезные команды для анализа логов:**
```bash
# Поиск ошибок в логах
docker logs n8n 2>&1 | grep -i "error\|exception\|fail"

# Проверка последних записей журнала
docker logs --tail 50 n8n

# Просмотр логов в режиме реального времени (полезно при отладке)
docker logs -f n8n
```

**Здоровый лог n8n должен содержать:**
- "n8n ready on" - подтверждение успешного запуска сервера
- "Connected to DB" - успешное подключение к базе данных
- "Webhooks waiting to be registered" - корректная инициализация системы webhooks
- Отсутствие повторяющихся ошибок или предупреждений

### 4.1.3. Проверка подключения n8n к базе данных

```bash
# Проверка подключения к PostgreSQL из контейнера n8n
docker exec n8n curl -s postgres:5432
```

**Что проверяем:**
- **Доступность базы данных**: Сервер PostgreSQL должен быть доступен из контейнера n8n
- **Корректность настроек соединения**: Проверка правильности настроек в переменных окружения

**Дополнительные проверки соединения с базой данных:**
```bash
# Проверка настроек подключения к БД в n8n
docker exec n8n env | grep DB_

# Проверка возможности подключения к PostgreSQL из n8n
docker exec n8n nc -zv postgres 5432

# Проверка подключения через psql (если доступен в контейнере)
docker exec n8n psql -h postgres -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();"
```

**Признаки проблем с подключением к БД:**
- Ошибки в логах: "Failed to connect to database", "ECONNREFUSED"
- Повторяющиеся попытки подключения
- Ошибки аутентификации или доступа

**Решение типичных проблем:**
- Проверьте правильность учетных данных в переменных окружения
- Убедитесь, что PostgreSQL запущен и принимает соединения
- Проверьте, что оба контейнера находятся в одной сети Docker

### 4.1.4. Тестирование базового workflow

Создание и выполнение базового рабочего процесса - это ключевой тест функциональности n8n.

**Шаги для создания тестового workflow через веб-интерфейс:**

1. **Вход в систему n8n:**
   - Откройте https://n8n.yourdomain.com
   - Используйте учетные данные администратора (N8N_DEFAULT_USER_EMAIL и N8N_DEFAULT_USER_PASSWORD)

2. **Создание нового workflow:**
   - Нажмите "Create workflow"
   - Назовите workflow "Test Workflow 1"

3. **Добавление и настройка узлов:**
   ```
   Cron-узел -> HTTP Request-узел -> JSON-узел
   ```
   - Настройте Cron-узел для запуска вручную
   - Настройте HTTP Request для запроса к https://jsonplaceholder.typicode.com/todos/1
   - Настройте JSON-узел для выбора нужных полей

4. **Тестирование выполнения:**
   - Нажмите "Execute workflow" для ручного запуска
   - Проверьте журнал выполнения на наличие ошибок
   - Убедитесь, что все узлы выполнились успешно (зеленые галочки)

**Скрипт для программного создания и тестирования workflow:**
```bash
# Создание тестового JSON для импорта workflow
cat > /tmp/test-workflow.json << EOF
{
  "name": "API Test Workflow",
  "nodes": [
    {
      "parameters": {},
      "name": "Start",
      "type": "n8n-nodes-base.start",
      "typeVersion": 1,
      "position": [
        250,
        300
      ]
    },
    {
      "parameters": {
        "url": "https://jsonplaceholder.typicode.com/todos/1",
        "options": {}
      },
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 1,
      "position": [
        450,
        300
      ]
    }
  ],
  "connections": {
    "Start": {
      "main": [
        [
          {
            "node": "HTTP Request",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  }
}
EOF

# Импорт workflow через API n8n
curl -k -X POST "https://n8n.yourdomain.com/rest/workflows" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -d @/tmp/test-workflow.json

# Активация workflow
WORKFLOW_ID=$(curl -k -s "https://n8n.yourdomain.com/rest/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq -r '.data[0].id')

curl -k -X POST "https://n8n.yourdomain.com/rest/workflows/${WORKFLOW_ID}/activate" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}"
```

**Проверка активных workflow через API:**
```bash
# Получение списка активных workflow
curl -k -s "https://n8n.yourdomain.com/rest/workflows?active=true" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq .
```

### 4.1.5. Функциональное тестирование n8n

#### 4.1.5.1. Вход в систему с учетными данными администратора

**Тестирование через UI:**
1. Откройте https://n8n.yourdomain.com в браузере
2. Введите учетные данные администратора
3. Убедитесь, что вход выполнен успешно и отображается главное меню

**Тестирование через API:**
```bash
# Получение токена аутентификации
curl -k -X POST "https://n8n.yourdomain.com/rest/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${N8N_DEFAULT_USER_EMAIL}\",\"password\":\"${N8N_DEFAULT_USER_PASSWORD}\"}"
```

**Проверяемые аспекты:**
- Корректная аутентификация с правильными учетными данными
- Блокировка доступа при неверных учетных данных
- Правильная обработка JWT-токенов и сессий
- Соблюдение политик безопасности

#### 4.1.5.2. Создание workflow с HTTP запросом

**Создание workflow с использованием различных типов узлов:**
- HTTP Request: для взаимодействия с внешними API
- Function: для написания пользовательской логики на JavaScript
- IF: для проверки условий и ветвления
- Postgres: для тестирования интеграции с базой данных

**Проверяемые аспекты:**
- Корректная визуализация workflow в интерфейсе
- Сохранение изменений в workflow
- Экспорт и импорт workflow
- Версионирование workflow (если включено)

#### 4.1.5.3. Проверка выполнения workflow по расписанию

**Настройка workflow с узлом Cron:**
1. Создайте workflow с узлом Cron, настроенным на выполнение каждую минуту
2. Добавьте узел для записи результатов (например, Telegram, Email или запись в файл)
3. Активируйте workflow и наблюдайте за его выполнением

**Проверка планировщика через API:**
```bash
# Получение списка активных executions
curl -k -s "https://n8n.yourdomain.com/rest/executions" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq .
```

**Что проверять:**
- Запуск workflow точно по расписанию
- Корректное выполнение всех узлов
- Обработка ошибок и повторные попытки
- Логирование выполнения

#### 4.1.5.4. Проверка выполнения workflow по webhook

**Настройка webhook workflow:**
1. Создайте workflow, начинающийся с Webhook-узла
2. Настройте обработку входящих данных
3. Активируйте workflow и запомните URL webhook'а

**Тестирование webhook:**
```bash
# Получение webhook URL
WEBHOOK_URL=$(curl -k -s "https://n8n.yourdomain.com/rest/workflows?active=true" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq -r '.data[] | select(.name=="Webhook Test") | .webhookUrl')

# Тестирование webhook с отправкой данных
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"test":"data","value":12345}'
```

**Что проверять:**
- Корректное получение данных через webhook
- Правильная обработка различных форматов данных (JSON, form-data)
- Безопасность webhook (если настроена аутентификация)
- Производительность при частых вызовах

#### 4.1.5.5. Тестирование подключения к внешним сервисам

**Проверка интеграций с внешними сервисами:**
1. Настройте подключения к внешним сервисам (через раздел Credentials)
2. Создайте тестовые workflow для каждого сервиса
3. Проверьте выполнение каждого workflow

**Примеры сервисов для тестирования:**
- Email (SMTP или сервисы вроде Gmail)
- Telegram
- Slack
- Google Sheets
- PostgreSQL (внешний, не локальный)
- HTTP API с аутентификацией

**Что проверять:**
- Успешное сохранение учетных данных
- Шифрование чувствительной информации
- Корректное использование учетных данных в workflow
- Обработка ошибок при недоступности сервиса

#### 4.1.5.6. Проверка работы с переменными окружения

**Тестирование переменных окружения:**
1. Настройте переменные окружения в n8n (через UI или файл .env)
2. Создайте workflow, использующий эти переменные
3. Проверьте правильность подстановки значений

**Скрипт для проверки переменных окружения:**
```bash
# Проверка настроенных переменных окружения в контейнере
docker exec n8n env | grep -v "PATH\|HOME\|PWD"

# Создание тестового workflow, использующего переменные
cat > /tmp/env-test-workflow.json << EOF
{
  "name": "Environment Variable Test",
  "nodes": [
    {
      "parameters": {},
      "name": "Start",
      "type": "n8n-nodes-base.start",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "functionCode": "return {env: process.env};"
      },
      "name": "Function",
      "type": "n8n-nodes-base.function",
      "typeVersion": 1,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Start": {
      "main": [[{"node": "Function", "type": "main", "index": 0}]]
    }
  }
}
EOF

# Импорт workflow
curl -k -X POST "https://n8n.yourdomain.com/rest/workflows" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -d @/tmp/env-test-workflow.json
```

**Что проверять:**
- Доступность переменных в workflow
- Безопасное хранение чувствительных данных
- Наследование переменных окружения из Docker

#### 4.1.5.7. Тестирование хранения учетных данных

**Проверка механизма хранения учетных данных:**
1. Создайте новые учетные данные различных типов (SMTP, API Key, OAuth2)
2. Используйте эти учетные данные в workflow
3. Проверьте шифрование учетных данных в базе данных

**Проверка шифрования учетных данных:**
```bash
# Проверка наличия ключа шифрования
docker exec n8n env | grep N8N_ENCRYPTION_KEY

# Проверка таблицы credentials в базе данных (без просмотра самих данных)
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT id, name, type FROM credentials_entity;"
```

**Что проверять:**
- Корректное сохранение учетных данных
- Шифрование чувствительной информации
- Возможность изменения и удаления учетных данных
- Правильное использование учетных данных в workflow

#### 4.1.5.8. Проверка экспорта/импорта workflow

**Тестирование экспорта workflow:**
```bash
# Экспорт workflow через API
WORKFLOW_ID=$(curl -k -s "https://n8n.yourdomain.com/rest/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq -r '.data[0].id')

curl -k -s "https://n8n.yourdomain.com/rest/workflows/${WORKFLOW_ID}" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" > /tmp/exported-workflow.json
```

**Тестирование импорта workflow:**
```bash
# Модификация экспортированного workflow
cat /tmp/exported-workflow.json | jq '.name = "Imported Test Workflow"' > /tmp/modified-workflow.json

# Импорт модифицированного workflow
curl -k -X POST "https://n8n.yourdomain.com/rest/workflows" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -d @/tmp/modified-workflow.json
```

**Что проверять:**
- Корректный экспорт всех элементов workflow
- Успешный импорт workflow без потери данных
- Обработка конфликтов имен
- Импорт workflow с зависимостями (учетные данные, переменные)

### 4.1.6. Тестирование производительности n8n

#### 4.1.6.1. Проверка потребления ресурсов

```bash
# Мониторинг использования ресурсов контейнером n8n
docker stats n8n --no-stream

# Проверка использования CPU и памяти при бездействии
docker stats n8n --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}"
```

**Что проверять:**
- Использование CPU в состоянии покоя (<5%)
- Потребление памяти в состоянии покоя (обычно 100-300 MB)
- Отсутствие утечек памяти при длительной работе

#### 4.1.6.2. Тестирование под нагрузкой

**Создание тестового нагрузочного workflow:**
1. Создайте workflow с узлом Webhook
2. Настройте узел для обработки данных и выполнения нескольких операций
3. Активируйте workflow

**Скрипт для нагрузочного тестирования:**
```bash
# Получение webhook URL
WEBHOOK_URL=$(curl -k -s "https://n8n.yourdomain.com/rest/workflows?active=true" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq -r '.data[] | select(.name=="Load Test") | .webhookUrl')

# Создание временного скрипта нагрузочного тестирования
cat > /tmp/load-test.sh << EOF
#!/bin/bash
for i in {1..100}; do
  curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "{\"test\":\"data\",\"iteration\":\$i}" &
  if [ \$((i % 10)) -eq 0 ]; then
    echo "Sent \$i requests..."
    sleep 1
  fi
done
wait
echo "Load test completed!"
EOF

chmod +x /tmp/load-test.sh
/tmp/load-test.sh
```

**Мониторинг ресурсов во время нагрузочного тестирования:**
```bash
# Запуск мониторинга в отдельном терминале
docker stats n8n

# Проверка логов во время нагрузки
docker logs -f n8n
```

**Что проверять:**
- Время отклика при различных уровнях нагрузки
- Стабильность работы при длительной нагрузке
- Корректная обработка параллельных запросов
- Потребление ресурсов при нагрузке

#### 4.1.6.3. Проверка параллельного выполнения workflow

**Тестирование параллельных запусков:**
1. Активируйте несколько workflow с разными триггерами
2. Запустите их одновременно через API или UI
3. Наблюдайте за их выполнением и потреблением ресурсов

**Скрипт для параллельного запуска workflow:**
```bash
# Получение ID всех workflow
WORKFLOW_IDS=$(curl -k -s "https://n8n.yourdomain.com/rest/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | jq -r '.data[].id')

# Параллельный запуск всех workflow
for id in $WORKFLOW_IDS; do
  echo "Starting workflow $id..."
  curl -k -X POST "https://n8n.yourdomain.com/rest/workflows/$id/run" \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -d "{}" &
done
wait
echo "All workflows started!"
```

**Что проверять:**
- Корректное выполнение всех параллельных workflow
- Отсутствие конфликтов при параллельной работе
- Распределение ресурсов между выполняющимися процессами
- Правильная обработка очереди выполнения

### 4.1.7. Проверка безопасности n8n

#### 4.1.7.1. Тестирование API-аутентификации

```bash
# Проверка запроса без API-ключа (должен вернуть ошибку)
curl -k -I "https://n8n.yourdomain.com/rest/workflows"

# Проверка запроса с неверным API-ключом
curl -k -I "https://n8n.yourdomain.com/rest/workflows" \
  -H "X-N8N-API-KEY: invalid-key"

# Проверка запроса с корректным API-ключом
curl -k -I "https://n8n.yourdomain.com/rest/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}"
```

**Что проверять:**
- Запросы без аутентификации должны быть отклонены (ошибка 401)
- Запросы с неверными учетными данными должны быть отклонены
- Корректные запросы должны быть обработаны

#### 4.1.7.2. Проверка шифрования данных

```bash
# Проверка настроек шифрования
docker exec n8n env | grep ENCRYPTION

# Проверка наличия ключа JWT
docker exec n8n env | grep JWT_SECRET
```

**Что проверять:**
- Наличие ключа шифрования (N8N_ENCRYPTION_KEY)
- Наличие секрета JWT (N8N_USER_MANAGEMENT_JWT_SECRET)
- Корректные настройки безопасности в конфигурации n8n

#### 4.1.7.3. Тестирование разграничения доступа (для multi-user setup)

**Проверка настроек пользователей:**
```bash
# Проверка настроек пользователей
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT id, email, role FROM user_entity;"

# Создание тестового пользователя через API (если настроено)
curl -k -X POST "https://n8n.yourdomain.com/rest/users" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -d '{"email":"test@example.com","firstName":"Test","lastName":"User","password":"securepassword","role":"user"}'
```

**Что проверять:**
- Корректное разграничение доступа между пользователями
- Правильная работа ролевой модели
- Изоляция данных между пользователями
- Управление пользователями через API/UI

### 4.1.8. Тестирование интеграции с другими компонентами стека

#### 4.1.8.1. Интеграция с PostgreSQL (внутренняя БД)

```bash
# Создание workflow для работы с PostgreSQL
cat > /tmp/postgres-test-workflow.json << EOF
{
  "name": "PostgreSQL Test",
  "nodes": [
    {
      "parameters": {},
      "name": "Start",
      "type": "n8n-nodes-base.start",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "credentials": {
          "name": "Postgres DB"
        },
        "operation": "executeQuery",
        "query": "SELECT version();"
      },
      "name": "Postgres",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 1,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Start": {
      "main": [[{"node": "Postgres", "type": "main", "index": 0}]]
    }
  }
}
EOF

# Импорт и выполнение workflow
# (Требуется предварительная настройка учетных данных PostgreSQL)
```

**Что проверять:**
- Корректное подключение к базе данных
- Выполнение запросов и получение результатов
- Обработка ошибок при проблемах с базой данных

#### 4.1.8.2. Интеграция с Redis

```bash
# Создание workflow для работы с Redis
# (Предполагается, что у вас есть Redis-узел в n8n)
```

**Что проверять:**
- Корректное подключение к Redis
- Операции чтения/записи данных
- Использование Redis для кеширования или очередей

#### 4.1.8.3. Интеграция с файловой системой

```bash
# Проверка доступа к файловой системе
docker exec n8n ls -la /home/node/.n8n

# Создание тестового файла
docker exec n8n bash -c "echo 'Test content' > /home/node/.n8n/test-file.txt"

# Проверка создания файла
docker exec n8n cat /home/node/.n8n/test-file.txt
```

**Что проверять:**
- Доступ к файловой системе контейнера
- Сохранение и чтение файлов
- Персистентность данных между перезапусками

### 4.1.9. Тестирование дополнительных функций n8n

#### 4.1.9.1. Проверка webhook timeout

```bash
# Создание workflow с длительной обработкой webhook
# Проверка таймаута при долгом выполнении
```

**Что проверять:**
- Корректная обработка длительных запросов
- Правильное поведение при таймауте
- Настройки таймаутов и их соблюдение

#### 4.1.9.2. Проверка обработки ошибок

```bash
# Создание workflow с преднамеренной ошибкой
# Настройка обработки ошибок
```

**Что проверять:**
- Корректная обработка исключений
- Логирование ошибок
- Механизмы повторных попыток
- Уведомления об ошибках

#### 4.1.9.3. Тестирование кастомных расширений (если используются)

```bash
# Проверка наличия кастомных узлов
docker exec n8n ls -la /home/node/.n8n/custom

# Создание workflow с использованием кастомных узлов
```

**Что проверять:**
- Корректная загрузка и работа кастомных узлов
- Интеграция кастомных узлов с основными функциями
- Обновление кастомных узлов при изменениях
