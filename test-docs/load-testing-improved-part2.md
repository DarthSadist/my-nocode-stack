# Руководство по нагрузочному тестированию стека (Часть 2)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования.

#### 9.2.3. Тестирование WordPress

```bash
# Базовый тест производительности WordPress
ab -n 2000 -c 100 -k -H "Accept-Encoding: gzip, deflate" https://wordpress.example.com/

# Расширенный тест с различными URL
for url in "/" "/wp-login.php" "/wp-json/wp/v2/posts"; do
  echo "--- Тестирование WordPress URL: $url ---"
  wrk -t4 -c50 -d30s https://wordpress.example.com$url
  sleep 10
done

# Создание скрипта для регулярного тестирования WordPress
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/wordpress-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование WordPress..."

# Функция для проведения тестирования различных URL
test_wordpress_url() {
  local url="https://wordpress.example.com"
  local endpoint=$1
  local description=$2
  
  echo "=== Тестирование $description ($url$endpoint) ==="
  
  # Тест с Apache Benchmark
  echo "Тест с Apache Benchmark (ab):"
  ab -n 1000 -c 50 -k -H "Accept-Encoding: gzip, deflate" "$url$endpoint"
  
  # Тест с wrk
  echo -e "\nТест с wrk:"
  wrk -t4 -c50 -d30s "$url$endpoint"
  
  # Тест с hey
  echo -e "\nТест с hey:"
  hey -n 1000 -c 50 "$url$endpoint"
  
  echo -e "\nТестирование $url$endpoint завершено\n"
}

# Тестирование разных страниц и функций WordPress
test_wordpress_url "/" "Главная страница"
test_wordpress_url "/wp-login.php" "Страница входа"
test_wordpress_url "/wp-json/wp/v2/posts" "REST API (посты)"
test_wordpress_url "/wp-json/wp/v2/pages" "REST API (страницы)"

# Тестирование админки (требует аутентификации)
echo "=== Тестирование админ-панели (требуется аутентификация) ==="
echo "Для полного тестирования админ-панели необходимо использовать инструменты,"
echo "поддерживающие сессии и cookies (например, JMeter или Gatling)"

# Проверка загрузки медиафайлов (если есть)
echo -e "\n=== Тестирование загрузки медиафайлов ==="
curl -s https://wordpress.example.com/wp-json/wp/v2/media | grep -o '"source_url":"[^"]*' | sed 's/"source_url":"//' | head -3 | while read media_url; do
  if [ -n "$media_url" ]; then
    echo "Тестирование загрузки медиафайла: $media_url"
    hey -n 500 -c 30 "$media_url"
  fi
done

echo "Нагрузочное тестирование WordPress завершено!"
EOF

chmod +x /tmp/wordpress-load-test.sh
```

**Рекомендации по оптимизации WordPress:**
- Установите и настройте плагин кеширования (например, W3 Total Cache или WP Super Cache)
- Используйте CDN для раздачи статических файлов (изображений, CSS, JavaScript)
- Оптимизируйте базу данных (регулярное обслуживание, индексы, очистка)
- Минимизируйте количество плагинов и используйте только оптимизированные
- Настройте кеширование объектов в Redis, если возможно

### 9.3. Нагрузочное тестирование API

#### 9.3.1. Тестирование n8n API

```bash
# Создание скрипта для тестирования webhook в n8n
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-n8n-webhook.sh << 'EOF'
#!/bin/bash

URL="https://n8n.example.com/webhook/test-load"
REQUESTS=500
CONCURRENT=50

echo "Тестирование n8n webhook с $REQUESTS запросами ($CONCURRENT параллельно)"

hey -n $REQUESTS -c $CONCURRENT -m POST \
  -H "Content-Type: application/json" \
  -d '{"test":"data","timestamp":"'$(date -Iseconds)'"}' \
  $URL

echo "Тестирование завершено"
EOF

chmod +x /tmp/test-n8n-webhook.sh

# Расширенный скрипт для тестирования n8n API
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/n8n-api-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование API n8n..."

# Создание тестовых данных для разных типов запросов
mkdir -p /tmp/n8n-test-data

# Данные для webhook
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/n8n-test-data/webhook-data.json << EOT
{
  "testData": "Данные для тестирования webhook",
  "number": 12345,
  "boolean": true,
  "array": [1, 2, 3, 4, 5],
  "timestamp": "$(date -Iseconds)"
}
EOT

# Функция для тестирования webhook с разным числом параллельных запросов
test_webhook() {
  local url="https://n8n.example.com/webhook/test-load"
  local requests=$1
  local concurrent=$2
  
  echo "=== Тестирование webhook: $requests запросов, $concurrent параллельно ==="
  
  hey -n $requests -c $concurrent -m POST \
    -H "Content-Type: application/json" \
    -D /tmp/n8n-test-data/webhook-data.json \
    $url
}

# Тестирование с разной нагрузкой
test_webhook 100 10
test_webhook 300 30
test_webhook 500 50
test_webhook 1000 100

# Тестирование REST API (если настроена аутентификация)
if [[ -n "$N8N_DEFAULT_USER_EMAIL" && -n "$N8N_DEFAULT_USER_PASSWORD" ]]; then
  echo -e "\n=== Тестирование REST API с аутентификацией ==="
  
  # Получение токена аутентификации
  TOKEN=$(curl -s -X POST "https://n8n.example.com/rest/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$N8N_DEFAULT_USER_EMAIL\",\"password\":\"$N8N_DEFAULT_USER_PASSWORD\"}" | grep -o '"token":"[^"]*' | sed 's/"token":"//')
  
  if [ -n "$TOKEN" ]; then
    echo "Токен аутентификации получен"
    
    # Тестирование GET-запросов к API
    echo "Тестирование GET-запросов к API"
    for endpoint in "/rest/workflows" "/rest/tags" "/rest/users"; do
      echo "Тестирование $endpoint"
      hey -n 100 -c 10 -m GET \
        -H "Authorization: Bearer $TOKEN" \
        "https://n8n.example.com$endpoint"
    done
  else
    echo "Не удалось получить токен аутентификации"
  fi
fi

echo "Нагрузочное тестирование API n8n завершено!"
EOF

chmod +x /tmp/n8n-api-load-test.sh
```

**Что анализировать при тестировании API:**
- **Время отклика по типам запросов**: Сравните время отклика для разных операций (GET, POST).
- **Пропускная способность API**: Определите максимальное число запросов, которое может обработать API.
- **Стабильность при длительной нагрузке**: Проверьте, не деградирует ли производительность со временем.
- **Обработка ошибок**: Оцените, как API обрабатывает ошибочные или некорректные запросы.

#### 9.3.2. Тестирование Flowise API

```bash
# Тестирование API Flowise для предсказаний
FLOW_ID=$(curl -s https://flowise.example.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -n "$FLOW_ID" ]; then
  # Создание скрипта для тестирования Flowise API
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-flowise-api.sh << EOF
#!/bin/bash

URL="https://flowise.example.com/api/v1/prediction/$FLOW_ID"
REQUESTS=100
CONCURRENT=10

echo "Тестирование Flowise API с $REQUESTS запросами ($CONCURRENT параллельно)"

hey -n $REQUESTS -c $CONCURRENT -m POST \\
  -H "Content-Type: application/json" \\
  -d '{
    "question":"Тестовый запрос для нагрузочного тестирования",
    "overrideConfig":{
      "sessionId":"load-test-session"
    }
  }' \\
  $URL

echo "Тестирование завершено"
EOF

  chmod +x /tmp/test-flowise-api.sh
fi

# Расширенный скрипт для тестирования API Flowise
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-api-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование API Flowise..."

# Создание тестовых данных
mkdir -p /tmp/flowise-test-data

# Получение ID тестового чатфлоу
FLOW_ID=$(curl -s https://flowise.example.com/api/v1/chatflows | grep -o '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -n "$FLOW_ID" ]; then
  echo "ID тестового чатфлоу: $FLOW_ID"
  
  # Создание тестовых данных для разных типов запросов
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-test-data/prediction-data.json << EOT
{
  "question": "Тестовый запрос для нагрузочного тестирования API Flowise",
  "overrideConfig": {
    "sessionId": "load-test-session-$(date +%s)"
  }
}
EOT

  # Функция для тестирования API предсказаний
  test_prediction_api() {
    local requests=$1
    local concurrent=$2
    
    echo "=== Тестирование API предсказаний: $requests запросов, $concurrent параллельно ==="
    
    hey -n $requests -c $concurrent -m POST \
      -H "Content-Type: application/json" \
      -D /tmp/flowise-test-data/prediction-data.json \
      "https://flowise.example.com/api/v1/prediction/$FLOW_ID"
  }
  
  # Тестирование с разной нагрузкой
  test_prediction_api 50 5
  test_prediction_api 100 10
  
  # Тестирование с разными запросами
  echo -e "\n=== Тестирование с различными запросами ==="
  
  # Создание файла с разными запросами
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-test-data/questions.txt << EOQ
Что такое искусственный интеллект?
Расскажи о нейронных сетях.
Как работает машинное обучение?
Какие существуют методы обработки естественного языка?
Что такое глубокое обучение?
EOQ
  
  cat /tmp/flowise-test-data/questions.txt | while read question; do
    echo "Тестирование вопроса: '$question'"
    
    # Создание временного файла с данными для конкретного вопроса
    # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/flowise-test-data/current-question.json << EOT
{
  "question": "$question",
  "overrideConfig": {
    "sessionId": "load-test-session-$(date +%s)"
  }
}
EOT
    
    # Выполнение запроса
    hey -n 20 -c 5 -m POST \
      -H "Content-Type: application/json" \
      -D /tmp/flowise-test-data/current-question.json \
      "https://flowise.example.com/api/v1/prediction/$FLOW_ID"
  done
  
  # Тестирование других API-эндпоинтов
  echo -e "\n=== Тестирование других API-эндпоинтов ==="
  
  hey -n 200 -c 20 "https://flowise.example.com/api/v1/health"
  hey -n 100 -c 10 "https://flowise.example.com/api/v1/components"
  hey -n 100 -c 10 "https://flowise.example.com/api/v1/chatflows"
else
  echo "Не удалось получить ID чатфлоу для тестирования"
fi

echo "Нагрузочное тестирование API Flowise завершено!"
EOF

chmod +x /tmp/flowise-api-load-test.sh
```

**Рекомендации по оптимизации API Flowise:**
- Внедрите кеширование часто запрашиваемых данных
- Оптимизируйте настройки модели для баланса между точностью и производительностью
- Реализуйте очередь запросов для обработки пиковых нагрузок
- Мониторьте время выполнения компонентов и оптимизируйте узкие места

#### 9.3.3. Тестирование WordPress REST API

```bash
# Тестирование WordPress REST API
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/test-wordpress-api.sh << 'EOF'
#!/bin/bash

BASE_URL="https://wordpress.example.com/wp-json"
REQUESTS=500
CONCURRENT=50

echo "Тестирование WordPress REST API с $REQUESTS запросами ($CONCURRENT параллельно)"

# Тест GET запросов (публичные данные)
for endpoint in "/wp/v2/posts" "/wp/v2/pages" "/wp/v2/categories"; do
  echo "--- Тестирование эндпоинта: $endpoint ---"
  hey -n $REQUESTS -c $CONCURRENT -m GET $BASE_URL$endpoint
  sleep 5
done

echo "Тестирование завершено"
EOF

chmod +x /tmp/test-wordpress-api.sh

# Расширенный скрипт для тестирования WordPress REST API
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/wordpress-api-load-test.sh << 'EOF'
#!/bin/bash

echo "Нагрузочное тестирование WordPress REST API..."

BASE_URL="https://wordpress.example.com/wp-json"

# Создание тестовых данных
mkdir -p /tmp/wordpress-test-data

# Функция для тестирования API-эндпоинтов
test_wp_api() {
  local endpoint=$1
  local method=${2:-GET}
  local requests=$3
  local concurrent=$4
  local description=$5
  
  echo "=== Тестирование $description ($method $BASE_URL$endpoint) ==="
  
  hey -n $requests -c $concurrent -m $method "$BASE_URL$endpoint"
}

# Тестирование публичных API-эндпоинтов
test_wp_api "/wp/v2/posts" "GET" 500 50 "Получение постов"
test_wp_api "/wp/v2/pages" "GET" 300 30 "Получение страниц"
test_wp_api "/wp/v2/categories" "GET" 200 20 "Получение категорий"
test_wp_api "/wp/v2/tags" "GET" 200 20 "Получение тегов"
test_wp_api "/wp/v2/media" "GET" 200 20 "Получение медиафайлов"
test_wp_api "/" "GET" 300 30 "Получение корневого эндпоинта"

# Тестирование поиска
test_wp_api "/wp/v2/search?search=test" "GET" 300 30 "Поиск"

# Тестирование с аутентификацией (если возможно)
echo -e "\n=== Тестирование с аутентификацией ==="
echo "Для тестирования аутентифицированных запросов необходимо получить токен."
echo "Можно использовать плагин JWT Authentication или аналогичный."

# Проверка наличия плагина JWT Auth
JWT_AVAILABLE=$(curl -s "$BASE_URL/jwt-auth/v1" | grep -c "JWT")

if [ $JWT_AVAILABLE -gt 0 ]; then
  echo "JWT Auth найден. Получение токена..."
  
  # Создание данных для аутентификации
  # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/wordpress-test-data/auth-data.json << EOT
{
  "username": "admin",
  "password": "your_password"
}
EOT
  
  # Получение токена
  TOKEN=$(curl -s -X POST "$BASE_URL/jwt-auth/v1/token" \
    -H "Content-Type: application/json" \
    -d @/tmp/wordpress-test-data/auth-data.json | grep -o '"token":"[^"]*' | sed 's/"token":"//')
  
  if [ -n "$TOKEN" ]; then
    echo "Токен получен. Тестирование защищенных эндпоинтов..."
    
    # Тестирование защищенных эндпоинтов
    hey -n 100 -c 10 -m GET \
      -H "Authorization: Bearer $TOKEN" \
      "$BASE_URL/wp/v2/users/me"
    
    # Создание поста
    # Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/load-testing
# cat > ~/my-nocode-stack/test-scripts/load-testing/wordpress-test-data/post-data.json << EOT
{
  "title": "Тестовый пост для нагрузочного тестирования",
  "content": "Содержимое тестового поста для нагрузочного тестирования API",
  "status": "publish"
}
EOT
    
    hey -n 50 -c 5 -m POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -D /tmp/wordpress-test-data/post-data.json \
      "$BASE_URL/wp/v2/posts"
  else
    echo "Не удалось получить токен"
  fi
else
  echo "JWT Auth не найден. Тестирование защищенных эндпоинтов невозможно."
fi

echo "Нагрузочное тестирование WordPress REST API завершено!"
EOF

chmod +x /tmp/wordpress-api-load-test.sh
```

**Рекомендации по оптимизации WordPress REST API:**
- Используйте кеширование на уровне API (плагины WP REST Cache или similar)
- Ограничьте количество возвращаемых полей и вложенных данных
- Настройте пагинацию для больших наборов данных
- Используйте Redis для кеширования объектов
- Оптимизируйте запросы в базу данных для API-эндпоинтов
