# Расширенное руководство по интеграционному тестированию стека

## 5. Интеграционное тестирование компонентов стека

После успешного тестирования отдельных компонентов необходимо провести комплексное интеграционное тестирование, чтобы убедиться в правильном взаимодействии всех сервисов между собой. Интеграционное тестирование позволяет выявить проблемы, которые могут возникать только при взаимодействии нескольких компонентов.

### 5.1. Подготовка к интеграционному тестированию

#### 5.1.1. Обеспечение тестовой среды

```bash
# Проверка работоспособности всех контейнеров
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v NAMES
```

**Что проверять:**
- **Статус всех контейнеров**: Все нужные контейнеры должны иметь статус "Up".
- **Время работы**: Контейнеры должны быть запущены достаточно долго для стабильной работы.
- **Порты**: Убедитесь, что настроено корректное проксирование портов.

**Подготовка тестовых данных:**
```bash
# Создание директории для тестовых данных
mkdir -p ~/my-nocode-stack/test-scripts/integration-test-data

# Подготовка тестовых файлов для различных сценариев
echo "Тестовый контент для интеграционного тестирования" > ~/my-nocode-stack/test-scripts/integration-test-data/test-file.txt
echo "Пример CSV-данных для импорта" > ~/my-nocode-stack/test-scripts/integration-test-data/test-data.csv
```

#### 5.1.2. Проверка внутренней связности сети

```bash
# Проверка сетевого взаимодействия между контейнерами
docker network inspect stack_default

# Проверка доступности сервисов друг для друга
docker exec n8n ping -c 2 flowise
docker exec n8n ping -c 2 postgres
docker exec n8n ping -c 2 redis
docker exec n8n ping -c 2 qdrant
docker exec flowise ping -c 2 n8n
docker exec flowise ping -c 2 postgres
docker exec wordpress ping -c 2 mariadb
```

**Что проверять:**
- **Успешное разрешение имен**: Проверьте, что все контейнеры могут найти друг друга по именам.
- **Подключение по протоколам**: Убедитесь, что необходимые порты открыты между контейнерами.
- **Задержки сети**: Проверьте время отклика (должно быть минимальным в локальной сети).

### 5.2. Тестирование взаимодействия между компонентами

#### 5.2.1. Интеграция n8n с PostgreSQL

```bash
# Скрипт для проверки соединения n8n с PostgreSQL
cat > ~/my-nocode-stack/test-scripts/check-n8n-postgres.sh << 'EOF'
#!/bin/bash

echo "Проверка подключения n8n к PostgreSQL..."

# Проверка доступности PostgreSQL из n8n
docker exec n8n nc -zv postgres 5432
if [ $? -eq 0 ]; then
  echo "Соединение установлено успешно!"
else
  echo "Ошибка подключения к PostgreSQL!"
  exit 1
fi

# Проверка настроек в переменных окружения n8n
docker exec n8n env | grep DB_POSTGRESDB_
echo "Настройки соединения с базой данных:"
docker exec n8n env | grep DB_TYPE
docker exec n8n env | grep DB_POSTGRESDB_HOST
docker exec n8n env | grep DB_POSTGRESDB_PORT
docker exec n8n env | grep DB_POSTGRESDB_DATABASE

# Проверка создания таблиц n8n в PostgreSQL
echo "Проверка наличия таблиц n8n в PostgreSQL:"
docker exec postgres psql -U $POSTGRES_USER -d $N8N_DB -c "\dt" | grep -i "workflow\|execution\|tag\|user"

echo "Проверка завершена!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-n8n-postgres.sh
```

**Тестирование интеграции через n8n UI:**
1. Откройте интерфейс n8n по адресу https://n8n.yourdomain.com
2. Создайте новый workflow с узлом PostgreSQL
3. Настройте соединение с БД (host: postgres, user: $POSTGRES_USER, password: $POSTGRES_PASSWORD)
4. Выполните тестовый запрос `SELECT 1 as test;`
5. Проверьте успешное выполнение и возвращение результата

#### 5.2.2. Интеграция Flowise с Qdrant

```bash
# Скрипт для проверки интеграции Flowise с Qdrant
cat > ~/my-nocode-stack/test-scripts/check-flowise-qdrant.sh << 'EOF'
#!/bin/bash

echo "Проверка интеграции Flowise с Qdrant..."

# Проверка доступности Qdrant из Flowise
docker exec flowise curl -s http://qdrant:6333/health
if [ $? -eq 0 ]; then
  echo "Соединение с Qdrant установлено успешно!"
else
  echo "Ошибка подключения к Qdrant!"
  exit 1
fi

# Создание тестовой коллекции в Qdrant
echo "Создание тестовой коллекции в Qdrant..."
curl -s -X PUT "http://localhost:6333/collections/flowise_test_integration" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'

# Добавление тестовых векторов
echo "Добавление тестовых векторов..."
curl -s -X PUT "http://localhost:6333/collections/flowise_test_integration/points" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
        "payload": {
          "text": "Тестовое сообщение для интеграции Flowise и Qdrant",
          "source": "integration_test"
        }
      }
    ]
  }'

echo "Тестовая коллекция создана!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-flowise-qdrant.sh
```

**Тестирование интеграции через Flowise UI:**
1. Откройте интерфейс Flowise по адресу https://flowise.yourdomain.com
2. Создайте новый чатфлоу с компонентом QdrantVectorStore
3. Настройте подключение к Qdrant (host: qdrant, port: 6333)
4. Выберите коллекцию "flowise_test_integration"
5. Добавьте текстовый ввод и компонент для семантического поиска
6. Протестируйте поток с запросом "тестовое сообщение"
7. Проверьте, что компонент успешно извлекает данные из Qdrant

#### 5.2.3. Интеграция n8n с Redis

```bash
# Проверка интеграции n8n с Redis
cat > ~/my-nocode-stack/test-scripts/check-n8n-redis.sh << 'EOF'
#!/bin/bash

echo "Проверка интеграции n8n с Redis..."

# Проверка доступности Redis из n8n
docker exec n8n redis-cli -h redis ping
if [ $? -eq 0 ]; then
  echo "Соединение с Redis установлено успешно!"
else
  echo "Ошибка подключения к Redis!"
  exit 1
fi

# Создание тестовых данных в Redis через n8n
docker exec n8n redis-cli -h redis SET "n8n_integration_test" "Test value from n8n"
RESULT=$(docker exec n8n redis-cli -h redis GET "n8n_integration_test")

if [ "$RESULT" = "Test value from n8n" ]; then
  echo "Тест записи/чтения данных в Redis успешен!"
else
  echo "Ошибка при работе с данными в Redis!"
  exit 1
fi

echo "Интеграция n8n с Redis работает корректно!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-n8n-redis.sh
```

**Тестирование интеграции через n8n UI:**
1. Откройте интерфейс n8n по адресу https://n8n.yourdomain.com
2. Создайте новый workflow с узлом Redis
3. Настройте соединение с Redis (host: redis, port: 6379)
4. Создайте последовательность операций: SET, GET, DEL
5. Проверьте успешное выполнение всех операций

#### 5.2.4. Интеграция WordPress с MariaDB

```bash
# Проверка интеграции WordPress с MariaDB
cat > ~/my-nocode-stack/test-scripts/check-wordpress-mariadb.sh << 'EOF'
#!/bin/bash

echo "Проверка интеграции WordPress с MariaDB..."

# Проверка соединения WordPress с MariaDB
docker exec wordpress php -r "if(new mysqli('mariadb', '$MYSQL_USER', '$MYSQL_PASSWORD', '$MYSQL_DATABASE')) { echo 'Соединение установлено успешно!\n'; } else { echo 'Ошибка подключения к MariaDB!\n'; exit(1); }"

# Проверка наличия таблиц WordPress в MariaDB
echo "Таблицы WordPress в MariaDB:"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW TABLES FROM $MYSQL_DATABASE;"

# Проверка возможности создания тестовой записи через WordPress API
echo "Создание тестовой записи в WordPress..."
# Получение токена аутентификации (требуется плагин JWT Auth)
TOKEN=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/jwt-auth/v1/token \
  --data "username=admin&password=your_password" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -n "$TOKEN" ]; then
  # Создание тестовой записи
  RESPONSE=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/wp/v2/posts \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "Тестовая запись интеграции",
      "content": "Это тестовая запись для проверки интеграции WordPress с MariaDB",
      "status": "publish"
    }')
  
  POST_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | sed 's/"id"://')
  
  if [ -n "$POST_ID" ]; then
    echo "Тестовая запись успешно создана (ID: $POST_ID)"
    
    # Проверка наличия записи в базе данных
    docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ID, post_title FROM $MYSQL_DATABASE.wp_posts WHERE ID = $POST_ID;"
  else
    echo "Не удалось создать тестовую запись!"
  fi
else
  echo "Не удалось получить токен аутентификации!"
fi

echo "Проверка интеграции WordPress с MariaDB завершена!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-wordpress-mariadb.sh
```

### 5.3. Тестирование потоков данных между компонентами

#### 5.3.1. Поток данных из n8n в Flowise

**Создание тестового сценария для передачи данных из n8n в Flowise:**

1. В n8n создайте новый workflow с именем "n8n-to-flowise-integration-test"
   - Добавьте триггер "Manual"
   - Добавьте узел "HTTP Request" для вызова API Flowise
   - Настройте запрос к API Flowise (например, POST к эндпоинту предсказания)
   - Добавьте тестовые данные для передачи

2. В Flowise создайте новый чатфлоу с именем "Flowise-n8n-integration"
   - Настройте API-интерфейс для приема данных от n8n
   - Добавьте обработку данных и возврат результата

3. Выполните n8n workflow и проверьте:
   - Успешная отправка данных в Flowise
   - Корректное получение и обработка данных Flowise
   - Возврат результата в n8n

```bash
# Скрипт для проверки интеграции n8n с Flowise
cat > ~/my-nocode-stack/test-scripts/check-n8n-flowise.sh << 'EOF'
#!/bin/bash

echo "Проверка интеграции n8n с Flowise..."

# Проверка доступности API Flowise из n8n
docker exec n8n curl -s https://flowise.yourdomain.com/api/v1/health
if [ $? -eq 0 ]; then
  echo "API Flowise доступно из n8n!"
else
  echo "Ошибка доступа к API Flowise из n8n!"
  exit 1
fi

# Получение ID тестового чатфлоу Flowise
FLOW_ID=$(curl -s https://flowise.yourdomain.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -n "$FLOW_ID" ]; then
  echo "ID тестового чатфлоу Flowise: $FLOW_ID"
  
  # Тестирование вызова API Flowise из n8n (имитация)
  docker exec n8n curl -s -X POST "https://flowise.yourdomain.com/api/v1/prediction/$FLOW_ID" \
    -H "Content-Type: application/json" \
    -d '{
      "question": "Тестовый запрос из n8n в Flowise",
      "overrideConfig": {
        "sessionId": "n8n-flowise-integration-test"
      }
    }'
  
  echo -e "\nПроверка завершена!"
else
  echo "Не удалось получить ID чатфлоу Flowise!"
fi
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-n8n-flowise.sh
```

#### 5.3.2. Поток данных из WordPress в n8n

**Создание тестового сценария для передачи данных из WordPress в n8n:**

1. В WordPress настройте webhook-уведомления для новых записей или комментариев
   - Установите плагин WP Webhooks (если не установлен)
   - Настройте webhook для отправки данных в n8n при создании новой записи

2. В n8n создайте новый workflow с именем "wordpress-to-n8n-integration-test"
   - Добавьте триггер "Webhook"
   - Настройте обработку входящих данных от WordPress
   - Добавьте узел для записи полученных данных (например, в базу данных или в файл)

3. Создайте тестовую запись в WordPress и проверьте:
   - Отправку webhook-уведомления в n8n
   - Корректное получение и обработку данных в n8n
   - Запись результата в целевое хранилище

```bash
# Скрипт для проверки интеграции WordPress с n8n
cat > ~/my-nocode-stack/test-scripts/check-wordpress-n8n.sh << 'EOF'
#!/bin/bash

echo "Проверка интеграции WordPress с n8n..."

# Проверка доступности n8n webhook из WordPress
docker exec wordpress curl -s https://n8n.yourdomain.com/webhook/test
if [ $? -eq 0 ]; then
  echo "Webhook n8n доступен из WordPress!"
else
  echo "Ошибка доступа к webhook n8n из WordPress!"
  exit 1
fi

# Создание тестовой записи в WordPress с отправкой webhook (имитация)
echo "Создание тестовой записи в WordPress и отправка webhook в n8n..."

# Получение токена аутентификации WordPress
TOKEN=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/jwt-auth/v1/token \
  --data "username=admin&password=your_password" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -n "$TOKEN" ]; then
  # Создание тестовой записи
  RESPONSE=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/wp/v2/posts \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "Тестовая запись для webhook n8n",
      "content": "Это тестовая запись для проверки интеграции WordPress с n8n через webhook",
      "status": "publish"
    }')
  
  POST_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | sed 's/"id"://')
  
  if [ -n "$POST_ID" ]; then
    echo "Тестовая запись успешно создана (ID: $POST_ID)"
    echo "Webhook должен был отправить данные в n8n (если настроен)"
  else
    echo "Не удалось создать тестовую запись!"
  fi
else
  echo "Не удалось получить токен аутентификации WordPress!"
fi

echo "Проверка интеграции WordPress с n8n завершена!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-wordpress-n8n.sh
```

#### 5.3.3. Поток данных из Flowise в Qdrant

**Создание тестового сценария для передачи данных из Flowise в Qdrant:**

1. В Flowise создайте новый чатфлоу для работы с Qdrant
   - Добавьте компонент TextInput
   - Добавьте компонент OpenAI для генерации или преобразования текста в эмбеддинги
   - Добавьте компонент QdrantVectorStore для сохранения векторов
   - Настройте сохранение результатов в коллекцию Qdrant

2. Запустите чатфлоу с тестовыми данными и проверьте:
   - Корректное преобразование текста в векторы
   - Успешное сохранение векторов в Qdrant
   - Возможность поиска по сохраненным векторам

```bash
# Скрипт для проверки интеграции Flowise с Qdrant
cat > ~/my-nocode-stack/test-scripts/check-flowise-qdrant-flow.sh << 'EOF'
#!/bin/bash

echo "Проверка потока данных из Flowise в Qdrant..."

# Проверка наличия тестовой коллекции в Qdrant
COLLECTION_INFO=$(curl -s -X GET "http://localhost:6333/collections/flowise_test_integration")
COLLECTION_EXISTS=$(echo $COLLECTION_INFO | grep -c "name")

if [ $COLLECTION_EXISTS -eq 0 ]; then
  echo "Создание тестовой коллекции в Qdrant..."
  curl -s -X PUT "http://localhost:6333/collections/flowise_test_integration" \
    -H "Content-Type: application/json" \
    -d '{
      "vectors": {
        "size": 384,
        "distance": "Cosine"
      }
    }'
fi

# Получение ID тестового чатфлоу Flowise для работы с Qdrant
FLOW_ID=$(curl -s https://flowise.yourdomain.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -n "$FLOW_ID" ]; then
  echo "ID тестового чатфлоу Flowise: $FLOW_ID"
  
  # Тестирование сохранения данных в Qdrant через Flowise API
  echo "Отправка запроса в Flowise для сохранения данных в Qdrant..."
  curl -s -X POST "https://flowise.yourdomain.com/api/v1/prediction/$FLOW_ID" \
    -H "Content-Type: application/json" \
    -d '{
      "question": "Сохрани этот текст в Qdrant: Тестирование потока данных из Flowise в Qdrant.",
      "overrideConfig": {
        "sessionId": "flowise-qdrant-integration-test"
      }
    }'
  
  # Проверка наличия данных в Qdrant
  sleep 5
  echo -e "\nПроверка наличия данных в Qdrant..."
  POINTS_COUNT=$(curl -s -X POST "http://localhost:6333/collections/flowise_test_integration/points/count" | grep -o '"count":[0-9]*' | sed 's/"count"://')
  
  echo "Количество точек в коллекции: $POINTS_COUNT"
  
  # Поиск по тестовому тексту
  echo "Выполнение тестового поиска в Qdrant..."
  curl -s -X POST "http://localhost:6333/collections/flowise_test_integration/points/search" \
    -H "Content-Type: application/json" \
    -d '{
      "filter": {
        "must": [
          {
            "key": "metadata.sessionId",
            "match": {
              "value": "flowise-qdrant-integration-test"
            }
          }
        ]
      },
      "limit": 1
    }'
  
  echo -e "\nПроверка потока данных из Flowise в Qdrant завершена!"
else
  echo "Не удалось получить ID чатфлоу Flowise!"
fi
EOF

chmod +x ~/my-nocode-stack/test-scripts/check-flowise-qdrant-flow.sh
```

### 5.4. Тестирование комплексных сценариев

#### 5.4.1. Сценарий многоэтапной обработки данных

**Тестирование полного цикла обработки данных от ввода до хранения:**

1. Создайте тестовые данные в формате CSV или JSON
2. Загрузите данные в WordPress как пост или через API
3. Настройте n8n для извлечения данных из WordPress
4. Обработайте данные в n8n (фильтрация, преобразование)
5. Передайте обработанные данные в Flowise для анализа AI
6. Сохраните результаты анализа в Qdrant
7. Извлеките и визуализируйте данные из Qdrant через n8n

```bash
# Скрипт для тестирования комплексного сценария обработки данных
cat > ~/my-nocode-stack/test-scripts/test-complex-data-flow.sh << 'EOF'
#!/bin/bash

echo "Тестирование комплексного сценария обработки данных..."

# Шаг 1: Создание тестовых данных
echo "Шаг 1: Подготовка тестовых данных..."
mkdir -p ~/my-nocode-stack/test-scripts/integration-test-data
cat > ~/my-nocode-stack/test-scripts/integration-test-data/test-products.csv << 'EOD'
id,name,category,description,price
1,"Смартфон XYZ","Электроника","Мощный смартфон с отличной камерой",599.99
2,"Ноутбук ABC","Электроника","Легкий и мощный ноутбук для работы",999.99
3,"Кофемашина DEF","Бытовая техника","Автоматическая кофемашина с капучинатором",349.50
4,"Умная колонка GHI","Умный дом","Колонка с голосовым ассистентом",129.99
5,"Наушники JKL","Аксессуары","Беспроводные наушники с шумоподавлением",199.99
EOD

# Шаг 2: Загрузка данных в WordPress через API
echo "Шаг 2: Загрузка данных в WordPress..."
TOKEN=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/jwt-auth/v1/token \
  --data "username=admin&password=your_password" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

if [ -n "$TOKEN" ]; then
  # Создание записи с данными CSV в содержимом
  RESPONSE=$(curl -s -X POST https://wordpress.yourdomain.com/wp-json/wp/v2/posts \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "title": "Тестовый каталог товаров",
      "content": "<!-- wp:code --><pre class=\"wp-block-code\"><code>'"$(cat ~/my-nocode-stack/test-scripts/integration-test-data/test-products.csv | sed 's/"/\\"/g')"'</code></pre><!-- /wp:code -->",
      "status": "publish"
    }')
  
  POST_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | sed 's/"id"://')
  
  if [ -n "$POST_ID" ]; then
    echo "Тестовая запись успешно создана в WordPress (ID: $POST_ID)"
    
    # Шаг 3-7: Эти шаги требуют настройки и запуска workflows в n8n и Flowise
    echo "Для завершения теста необходимо выполнить следующие шаги вручную:"
    echo "3. Запустите workflow 'extract-data-from-wordpress' в n8n"
    echo "4. Проверьте обработку данных в n8n"
    echo "5. Убедитесь, что данные переданы в Flowise"
    echo "6. Проверьте сохранение результатов в Qdrant"
    echo "7. Выполните поисковый запрос к Qdrant через n8n"
  else
    echo "Не удалось создать тестовую запись в WordPress!"
  fi
else
  echo "Не удалось получить токен аутентификации WordPress!"
fi

echo "Тестирование комплексного сценария завершено!"
EOF

chmod +x ~/my-nocode-stack/test-scripts/test-complex-data-flow.sh
```

#### 5.4.2. Сценарий интерактивного пользовательского взаимодействия

**Тестирование пользовательского сценария с несколькими компонентами:**

1. Смоделируйте пользовательский запрос через n8n webhook
2. Обработайте запрос в n8n и извлеките ключевую информацию
3. Передайте запрос в Flowise для генерации ответа с помощью AI
4. Сохраните историю взаимодействия в Redis
5. Запишите результаты в WordPress как новую запись или комментарий
6. Отправьте уведомление через n8n о завершении процесса
