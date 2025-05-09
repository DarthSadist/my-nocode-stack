# Руководство по тестированию безопасности стека (Часть 2)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования, где раздел 10 посвящен проверке безопасности.

### 10.3. Проверка сетевой безопасности (продолжение)

#### 10.3.3. Проверка настроек межсетевого экрана для контейнеров

```bash
# Скрипт для проверки межсетевого экрана Docker
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/docker-firewall-check.sh << 'EOF'
#!/bin/bash

echo "Проверка настроек межсетевого экрана для контейнеров..."

# Проверка правил iptables, связанных с Docker
echo "=== Правила iptables для Docker ==="
iptables -L -n | grep DOCKER

# Проверка правил для сетевых мостов Docker
echo -e "\n=== Правила для сетевых мостов Docker ==="
iptables -L DOCKER-USER -n 2>/dev/null || echo "Цепочка DOCKER-USER не найдена"

# Проверка перенаправления портов
echo -e "\n=== Проверка перенаправления портов ==="
iptables -t nat -L DOCKER -n

# Проверка изоляции сетей Docker
echo -e "\n=== Проверка изоляции сетей Docker ==="
docker network ls --format "{{.Name}}" | while read network; do
  echo "Проверка сети: $network"
  docker network inspect $network | jq '.[0].Options'
done

echo "Проверка настроек межсетевого экрана для контейнеров завершена"
EOF

chmod +x /tmp/docker-firewall-check.sh
```

### 10.4. Проверка аутентификации и авторизации

#### 10.4.1. Проверка механизмов аутентификации

```bash
# Скрипт для проверки механизмов аутентификации
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/auth-security-check.sh << 'EOF'
#!/bin/bash

echo "Проверка механизмов аутентификации..."

# Функция для проверки форм входа
check_login_form() {
  local name=$1
  local url=$2
  
  echo "=== Проверка формы входа: $name ($url) ==="
  
  # Проверка доступности страницы входа
  curl -s -I "$url" | head -1
  
  # Проверка наличия базовых элементов безопасности
  curl -s "$url" | grep -i -E "csrf|token|captcha" || echo "Не найдены элементы защиты от CSRF/брутфорса"
  
  # Проверка использования HTTPS
  if [[ "$url" != https://* ]]; then
    echo "ВНИМАНИЕ: Форма входа не использует HTTPS!"
  fi
}

# Проверка форм входа для различных компонентов
check_login_form "WordPress" "https://wordpress.example.com/wp-login.php"
check_login_form "n8n" "https://n8n.example.com/signin"
check_login_form "Flowise" "https://flowise.example.com/login"

# Проверка защиты от атак грубой силы
echo -e "\n=== Проверка защиты от атак грубой силы ==="
# Это тестовая проверка, которая не выполняет реальную атаку
for url in "https://wordpress.example.com/wp-login.php" "https://n8n.example.com/signin"; do
  echo "Тестирование URL: $url"
  for i in {1..3}; do
    # Безопасная проверка: отправка заведомо неверных данных
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=test_user&password=test_password_$i")
    echo "Попытка $i: Код ответа $response"
    
    # Если обнаружено потенциальное ограничение попыток, прекращаем проверку
    if [ "$response" = "429" ]; then
      echo "Обнаружено ограничение частоты запросов (rate limiting). Хороший знак!"
      break
    fi
  done
done

# Проверка настроек сессий
echo -e "\n=== Проверка настроек сессий ==="
for url in "https://wordpress.example.com" "https://n8n.example.com" "https://flowise.example.com"; do
  echo "URL: $url"
  curl -s -I "$url" | grep -i "set-cookie"
done

echo "Проверка механизмов аутентификации завершена"
EOF

chmod +x /tmp/auth-security-check.sh
```

#### 10.4.2. Проверка настроек авторизации

```bash
# Скрипт для проверки настроек авторизации
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/authorization-check.sh << 'EOF'
#!/bin/bash

echo "Проверка настроек авторизации..."

# Проверка настроек авторизации в PostgreSQL
echo "=== Проверка авторизации в PostgreSQL ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT rolname, rolcreaterole, rolcreatedb FROM pg_roles;"
docker exec postgres psql -U $POSTGRES_USER -c "SELECT table_name, grantee, privilege_type FROM information_schema.table_privileges WHERE table_schema = 'public';"

# Проверка настроек авторизации в MariaDB
echo -e "\n=== Проверка авторизации в MariaDB ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW GRANTS FOR '$MYSQL_USER'@'%';"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT User, Host, Grant_priv, Super_priv FROM mysql.user;"

# Проверка настроек авторизации в WordPress
echo -e "\n=== Проверка авторизации в WordPress ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ID, user_login, user_nicename, user_email, user_status FROM $MYSQL_DATABASE.wp_users;"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user_id, meta_key, meta_value FROM $MYSQL_DATABASE.wp_usermeta WHERE meta_key LIKE '%capabilities%';"

echo "Проверка настроек авторизации завершена"
EOF

chmod +x /tmp/authorization-check.sh
```

#### 10.4.3. Проверка защиты API

```bash
# Скрипт для тестирования защиты API
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/api-security-check.sh << 'EOF'
#!/bin/bash

echo "Тестирование защиты API..."

# Проверка защиты API WordPress
echo "=== Проверка защиты API WordPress ==="
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://wordpress.example.com/wp-json/
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://wordpress.example.com/wp-json/wp/v2/users/

# Проверка защиты API n8n
echo -e "\n=== Проверка защиты API n8n ==="
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://n8n.example.com/rest/workflows
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://n8n.example.com/rest/credentials

# Проверка защиты API Flowise
echo -e "\n=== Проверка защиты API Flowise ==="
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://flowise.example.com/api/v1/chatflows
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" https://flowise.example.com/api/v1/components

# Проверка API Qdrant
echo -e "\n=== Проверка защиты API Qdrant ==="
curl -s -o /dev/null -w "Код ответа: %{http_code}\n" http://localhost:6333/collections

# Проверка наличия ограничений частоты запросов (rate limiting)
echo -e "\n=== Проверка наличия rate limiting ==="
for i in {1..10}; do
  curl -s -o /dev/null -w "Попытка $i - Код ответа: %{http_code}\n" https://wordpress.example.com/wp-json/wp/v2/posts
  sleep 0.5
done

echo "Тестирование защиты API завершено"
EOF

chmod +x /tmp/api-security-check.sh
```

### 10.5. Проверка веб-безопасности

#### 10.5.1. Сканирование веб-уязвимостей

```bash
# Скрипт для сканирования веб-уязвимостей
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/web-vulnerability-scan.sh << 'EOF'
#!/bin/bash

echo "Сканирование веб-уязвимостей..."

# Функция для базового сканирования с помощью nikto
scan_with_nikto() {
  local name=$1
  local url=$2
  
  echo "=== Сканирование $name с помощью Nikto ==="
  nikto -h "$url" -o "/tmp/nikto-$name.txt"
  echo "Результаты сохранены в /tmp/nikto-$name.txt"
}

# Функция для сканирования с помощью wapiti
scan_with_wapiti() {
  local name=$1
  local url=$2
  
  echo "=== Сканирование $name с помощью Wapiti ==="
  wapiti -u "$url" -o "/tmp/wapiti-$name" -f txt
  echo "Результаты сохранены в /tmp/wapiti-$name"
}

# Функция для сканирования с помощью OWASP ZAP (если установлен)
scan_with_zap() {
  local name=$1
  local url=$2
  
  if command -v zap > /dev/null; then
    echo "=== Сканирование $name с помощью OWASP ZAP ==="
    zap -cmd -silent -quickurl "$url" -quickout "/tmp/zap-$name.html"
    echo "Результаты сохранены в /tmp/zap-$name.html"
  else
    echo "OWASP ZAP не установлен или не найден в PATH"
  fi
}

# Сканирование компонентов с веб-интерфейсом
for component in "wordpress" "n8n" "flowise"; do
  url="https://$component.example.com"
  echo -e "\n=== Сканирование $component ($url) ==="
  
  # Базовая проверка доступности
  if curl -s -I "$url" | grep -q "200 OK"; then
    echo "$component доступен для сканирования"
    
    # Сканирование с помощью различных инструментов
    scan_with_nikto $component $url
    scan_with_wapiti $component $url
    scan_with_zap $component $url
  else
    echo "Сервис $component недоступен"
  fi
done

echo "Сканирование веб-уязвимостей завершено"
EOF

chmod +x /tmp/web-vulnerability-scan.sh
```

#### 10.5.2. Проверка защиты от атак XSS и CSRF

```bash
# Скрипт для проверки защиты от XSS и CSRF
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/xss-csrf-check.sh << 'EOF'
#!/bin/bash

echo "Проверка защиты от XSS и CSRF..."

# Функция для проверки защиты от XSS
check_xss_protection() {
  local name=$1
  local url=$2
  
  echo "=== Проверка защиты от XSS для $name ($url) ==="
  
  # Проверка заголовков безопасности
  echo "Заголовки безопасности:"
  curl -s -I "$url" | grep -i -E "Content-Security-Policy|X-XSS-Protection|X-Content-Type-Options"
  
  # Проверка обработки специальных символов
  echo "Проверка обработки специальных символов:"
  curl -s "$url/?test=<script>alert(1)</script>" | grep -c "<script>alert(1)</script>" || echo "Специальные символы обрабатываются корректно"
}

# Функция для проверки защиты от CSRF
check_csrf_protection() {
  local name=$1
  local url=$2
  
  echo "=== Проверка защиты от CSRF для $name ($url) ==="
  
  # Проверка наличия токенов CSRF в формах
  curl -s "$url" | grep -i -E "csrf|token" > /dev/null
  if [ $? -eq 0 ]; then
    echo "Найдены потенциальные токены CSRF"
  else
    echo "ВНИМАНИЕ: Не найдены токены CSRF в HTML"
  fi
  
  # Проверка cookie с флагом SameSite
  echo "Проверка атрибутов cookie:"
  curl -s -I "$url" | grep -i "Set-Cookie" | grep -i "SameSite"
}

# Проверка компонентов с веб-интерфейсом
for component in "wordpress" "n8n" "flowise"; do
  url="https://$component.example.com"
  echo -e "\n=== Проверка $component ($url) ==="
  
  # Базовая проверка доступности
  if curl -s -I "$url" | grep -q "200 OK"; then
    check_xss_protection $component $url
    check_csrf_protection $component $url
  else
    echo "Сервис $component недоступен"
  fi
done

echo "Проверка защиты от XSS и CSRF завершена"
EOF

chmod +x /tmp/xss-csrf-check.sh
```

#### 10.5.3. Проверка защиты от инъекций SQL

```bash
# Скрипт для проверки защиты от SQL-инъекций
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/sql-injection-check.sh << 'EOF'
#!/bin/bash

echo "Проверка защиты от SQL-инъекций..."

# ВАЖНО: Этот скрипт предназначен только для базовой проверки и не выполняет реальные атаки
# Все тесты выполняются безопасно, без реального вмешательства в работу системы

# Функция для безопасной проверки потенциальных уязвимостей SQL-инъекций
check_sql_injection() {
  local name=$1
  local url=$2
  local param=$3
  
  echo "=== Проверка защиты от SQL-инъекций для $name ($url) ==="
  
  # Создание тестовых запросов (безопасное тестирование)
  local test_values=(
    "1' OR '1'='1"
    "1; DROP TABLE users--"
    "' UNION SELECT 1,2,3--"
  )
  
  for test in "${test_values[@]}"; do
    # URL-кодирование тестового значения
    encoded_test=$(echo -n "$test" | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')
    
    # Выполнение безопасного запроса
    echo "Тестовый запрос: $param=$test"
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url?$param=$encoded_test")
    echo "Код ответа: $response"
    
    # Проверка наличия признаков защиты
    if [ "$response" = "400" ] || [ "$response" = "403" ]; then
      echo "Обнаружены признаки защиты от SQL-инъекций"
    fi
  done
}

# Безопасная проверка WordPress
check_sql_injection "WordPress Posts" "https://wordpress.example.com/" "p"
check_sql_injection "WordPress Search" "https://wordpress.example.com/" "s"

# Безопасная проверка n8n (URL для примера)
check_sql_injection "n8n Workflows" "https://n8n.example.com/rest/workflows" "filter"

echo "Проверка защиты от SQL-инъекций завершена"
EOF

chmod +x /tmp/sql-injection-check.sh
```

### 10.6. Проверка защиты данных

#### 10.6.1. Проверка шифрования данных

```bash
# Скрипт для проверки шифрования данных
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/encryption-check.sh << 'EOF'
#!/bin/bash

echo "Проверка шифрования данных..."

# Проверка шифрования SSL/TLS
echo "=== Проверка SSL/TLS конфигурации ==="
for domain in localhost n8n.example.com flowise.example.com wordpress.example.com; do
  echo "Проверка $domain"
  echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | grep "Cipher is"
  echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | grep "Protocol  :"
done

# Проверка шифрования данных в PostgreSQL
echo -e "\n=== Проверка шифрования в PostgreSQL ==="
docker exec postgres psql -U $POSTGRES_USER -c "SHOW ssl;"
docker exec postgres psql -U $POSTGRES_USER -c "SELECT datname, ssl, client_addr FROM pg_stat_ssl JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid;"

# Проверка шифрования в n8n
echo -e "\n=== Проверка шифрования в n8n ==="
docker exec n8n bash -c 'env | grep -i "encryption"'

# Проверка шифрования в Redis
echo -e "\n=== Проверка шифрования в Redis ==="
docker exec redis redis-cli CONFIG GET tls-*

# Проверка безопасного хранения паролей в WordPress
echo -e "\n=== Проверка хранения паролей в WordPress ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ID, user_login, user_pass FROM $MYSQL_DATABASE.wp_users LIMIT 3;" | grep -v "user_pass"

echo "Проверка шифрования данных завершена"
EOF

chmod +x /tmp/encryption-check.sh
```
