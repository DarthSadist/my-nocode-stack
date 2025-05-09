# Руководство по тестированию безопасности стека (Часть 3)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования, где раздел 10 посвящен проверке безопасности.

### 10.6. Проверка защиты данных (продолжение)

#### 10.6.2. Проверка резервного копирования и восстановления

```bash
# Скрипт для проверки системы резервного копирования
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/backup-security-check.sh << 'EOF'
#!/bin/bash

echo "Проверка безопасности системы резервного копирования..."

# Проверка наличия резервных копий
echo "=== Проверка наличия резервных копий ==="
if [ -d "/backup" ]; then
  echo "Директория резервных копий: /backup"
  find /backup -type f -name "*.sql" -o -name "*.dump" -o -name "*.tar" -o -name "*.gz" | sort
else
  echo "Директория /backup не найдена"
fi

# Проверка прав доступа к резервным копиям
echo -e "\n=== Проверка прав доступа к резервным копиям ==="
if [ -d "/backup" ]; then
  ls -la /backup
  find /backup -type f -name "*.sql" -o -name "*.dump" -o -name "*.tar" -o -name "*.gz" -exec ls -la {} \;
else
  echo "Директория /backup не найдена"
fi

# Проверка шифрования резервных копий
echo -e "\n=== Проверка шифрования резервных копий ==="
if [ -d "/backup" ]; then
  find /backup -type f -name "*.enc" -o -name "*.gpg" | wc -l
  if [ $? -eq 0 ]; then
    echo "Обнаружены зашифрованные резервные копии"
  else
    echo "ВНИМАНИЕ: Не обнаружено зашифрованных резервных копий"
  fi
else
  echo "Директория /backup не найдена"
fi

# Проверка скриптов резервного копирования
echo -e "\n=== Проверка скриптов резервного копирования ==="
for script in /etc/cron.daily/backup* /usr/local/bin/backup* /home/*/backup*.sh; do
  if [ -f "$script" ]; then
    echo "Найден скрипт резервного копирования: $script"
    grep -i "encrypt\|gpg\|openssl" "$script" > /dev/null
    if [ $? -eq 0 ]; then
      echo "Скрипт содержит операции шифрования"
    else
      echo "ВНИМАНИЕ: Скрипт не содержит операций шифрования"
    fi
  fi
done

echo "Проверка безопасности системы резервного копирования завершена"
EOF

chmod +x /tmp/backup-security-check.sh
```

#### 10.6.3. Проверка защиты от утечки данных

```bash
# Скрипт для проверки защиты от утечки данных
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/data-leakage-check.sh << 'EOF'
#!/bin/bash

echo "Проверка защиты от утечки данных..."

# Проверка публично доступных директорий
echo "=== Проверка публично доступных директорий ==="
for url in "https://wordpress.example.com" "https://n8n.example.com" "https://flowise.example.com"; do
  echo "Проверка URL: $url"
  
  # Проверка директорий с конфигурацией
  for dir in "wp-content" "wp-includes" "wp-admin" "config" "backup" "install" "setup" ".git"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url/$dir/")
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
      echo "ВНИМАНИЕ: Директория $dir доступна ($code)"
    else
      echo "Директория $dir недоступна ($code) - хорошо"
    fi
  done
done

# Проверка наличия файлов с чувствительной информацией в веб-доступе
echo -e "\n=== Проверка наличия файлов с чувствительной информацией ==="
for url in "https://wordpress.example.com" "https://n8n.example.com" "https://flowise.example.com"; do
  echo "Проверка URL: $url"
  
  # Проверка чувствительных файлов
  for file in "wp-config.php" ".env" "config.json" ".htaccess" "backup.sql" "dump.sql" "database.sql" "readme.html" "license.txt"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url/$file")
    if [ "$code" = "200" ]; then
      echo "ВНИМАНИЕ: Файл $file доступен ($code)"
    else
      echo "Файл $file недоступен ($code) - хорошо"
    fi
  done
done

# Проверка заголовков HTTP на утечку информации
echo -e "\n=== Проверка заголовков HTTP на утечку информации ==="
for url in "https://wordpress.example.com" "https://n8n.example.com" "https://flowise.example.com"; do
  echo "Проверка URL: $url"
  curl -s -I "$url" | grep -i -E "Server:|X-Powered-By:|X-AspNet-Version:|X-Debug|framework|generator|cms"
done

# Проверка доступа к директориям в WordPress
echo -e "\n=== Проверка доступа к директориям в WordPress ==="
for dir in "wp-content/uploads" "wp-content/plugins" "wp-content/themes"; do
  url="https://wordpress.example.com/$dir"
  is_directory_listing=$(curl -s "$url" | grep -i "Index of")
  if [ -n "$is_directory_listing" ]; then
    echo "ВНИМАНИЕ: В директории $url включен листинг содержимого"
  else
    echo "В директории $url листинг содержимого отключен - хорошо"
  fi
done

echo "Проверка защиты от утечки данных завершена"
EOF

chmod +x /tmp/data-leakage-check.sh
```

### 10.7. Проверка защиты баз данных

#### 10.7.1. Проверка безопасности PostgreSQL

```bash
# Скрипт для проверки безопасности PostgreSQL
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/postgres-security-check.sh << 'EOF'
#!/bin/bash

echo "Проверка безопасности PostgreSQL..."

# Проверка версии PostgreSQL
echo "=== Версия PostgreSQL ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT version();"

# Проверка настроек конфигурации безопасности
echo -e "\n=== Проверка настроек конфигурации безопасности ==="
docker exec postgres psql -U $POSTGRES_USER -c "SHOW ssl;"
docker exec postgres psql -U $POSTGRES_USER -c "SHOW password_encryption;"
docker exec postgres psql -U $POSTGRES_USER -c "SHOW log_connections;"
docker exec postgres psql -U $POSTGRES_USER -c "SHOW log_disconnections;"
docker exec postgres psql -U $POSTGRES_USER -c "SHOW log_statement;"

# Проверка пользователей и их прав
echo -e "\n=== Проверка пользователей и их прав ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolreplication FROM pg_roles;"

# Проверка настроек доступа (pg_hba.conf)
echo -e "\n=== Проверка настроек доступа (pg_hba.conf) ==="
docker exec postgres grep -v "^#" /var/lib/postgresql/data/pg_hba.conf | grep -v "^$"

# Проверка публичного доступа к таблицам
echo -e "\n=== Проверка публичного доступа к таблицам ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = 'public';"
docker exec postgres psql -U $POSTGRES_USER -c "SELECT grantor, grantee, table_schema, table_name, privilege_type FROM information_schema.table_privileges WHERE grantee = 'PUBLIC';"

# Проверка активных подключений
echo -e "\n=== Проверка активных подключений ==="
docker exec postgres psql -U $POSTGRES_USER -c "SELECT pid, usename, datname, client_addr, client_port, application_name, backend_start FROM pg_stat_activity;"

echo "Проверка безопасности PostgreSQL завершена"
EOF

chmod +x /tmp/postgres-security-check.sh
```

#### 10.7.2. Проверка безопасности MariaDB

```bash
# Скрипт для проверки безопасности MariaDB
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/mariadb-security-check.sh << 'EOF'
#!/bin/bash

echo "Проверка безопасности MariaDB..."

# Проверка версии MariaDB
echo "=== Версия MariaDB ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT VERSION();"

# Проверка настроек конфигурации безопасности
echo -e "\n=== Проверка настроек конфигурации безопасности ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE 'version%';"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE 'ssl%';"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE '%password%';"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE 'log_bin';"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE 'have_ssl';"

# Проверка пользователей и их прав
echo -e "\n=== Проверка пользователей и их прав ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user, host, password_expired FROM mysql.user;"
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user, host, Grant_priv, Super_priv, File_priv FROM mysql.user;"

# Проверка анонимного доступа
echo -e "\n=== Проверка анонимного доступа ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user, host FROM mysql.user WHERE user = '';"

# Проверка привилегий пользователей
echo -e "\n=== Проверка привилегий пользователей ==="
for user in $(docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -s -e "SELECT DISTINCT user FROM mysql.user;"); do
  echo "Привилегии для пользователя: $user"
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW GRANTS FOR '$user'@'%';" 2>/dev/null || \
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW GRANTS FOR '$user'@'localhost';" 2>/dev/null
done

# Проверка активных подключений
echo -e "\n=== Проверка активных подключений ==="
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW PROCESSLIST;"

echo "Проверка безопасности MariaDB завершена"
EOF

chmod +x /tmp/mariadb-security-check.sh
```

#### 10.7.3. Проверка безопасности Redis

```bash
# Скрипт для проверки безопасности Redis
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/redis-security-check.sh << 'EOF'
#!/bin/bash

echo "Проверка безопасности Redis..."

# Проверка версии Redis
echo "=== Версия Redis ==="
docker exec redis redis-cli info | grep redis_version

# Проверка настроек конфигурации безопасности
echo -e "\n=== Проверка настроек конфигурации безопасности ==="
docker exec redis redis-cli CONFIG GET protected-mode
docker exec redis redis-cli CONFIG GET bind
docker exec redis redis-cli CONFIG GET port
docker exec redis redis-cli CONFIG GET requirepass
docker exec redis redis-cli CONFIG GET maxmemory-policy
docker exec redis redis-cli CONFIG GET rename-command

# Проверка доступности Redis
echo -e "\n=== Проверка доступности Redis ==="
nc -zv localhost 6379
nc -zv $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis) 6379

# Проверка активных подключений
echo -e "\n=== Проверка активных подключений ==="
docker exec redis redis-cli CLIENT LIST

# Проверка доступа к командам Redis
echo -e "\n=== Проверка доступа к командам Redis ==="
docker exec redis redis-cli CONFIG GET *

# Проверка доступа к ключам
echo -e "\n=== Проверка доступа к ключам ==="
docker exec redis redis-cli --scan --pattern "*"

echo "Проверка безопасности Redis завершена"
EOF

chmod +x /tmp/redis-security-check.sh
```

### 10.8. Комплексная проверка безопасности

#### 10.8.1. Автоматизированное сканирование безопасности

```bash
# Скрипт для автоматизированного комплексного сканирования безопасности
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/automated-security-scan.sh << 'EOF'
#!/bin/bash

echo "Автоматизированное комплексное сканирование безопасности..."

# Определение целевых компонентов и их URL
declare -A targets=(
  ["wordpress"]="https://wordpress.example.com"
  ["n8n"]="https://n8n.example.com"
  ["flowise"]="https://flowise.example.com"
)

# Создание директории для результатов
RESULTS_DIR="/tmp/security-scan-results"
mkdir -p "$RESULTS_DIR"
echo "Результаты сканирования будут сохранены в $RESULTS_DIR"

# Функция для сканирования с помощью nikto
scan_with_nikto() {
  local name=$1
  local url=$2
  
  echo "=== Сканирование $name с помощью Nikto ==="
  nikto -h "$url" -o "$RESULTS_DIR/nikto-$name.txt"
  echo "Результаты сохранены в $RESULTS_DIR/nikto-$name.txt"
}

# Функция для сканирования с помощью sslyze
scan_ssl() {
  local name=$1
  local url=$2
  
  # Извлечение домена из URL
  domain=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
  
  echo "=== Сканирование SSL для $name ($domain) ==="
  sslyze --regular "$domain" > "$RESULTS_DIR/sslyze-$name.txt" 2>/dev/null || \
  echo "Не удалось выполнить сканирование SSL для $domain"
  echo "Результаты сохранены в $RESULTS_DIR/sslyze-$name.txt"
}

# Функция для сканирования с помощью nmap
scan_with_nmap() {
  local name=$1
  local url=$2
  
  # Извлечение домена из URL
  domain=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
  
  echo "=== Сканирование $name с помощью Nmap ==="
  nmap -sV --script "http-*,ssl-*" -p 80,443 "$domain" -oN "$RESULTS_DIR/nmap-$name.txt"
  echo "Результаты сохранены в $RESULTS_DIR/nmap-$name.txt"
}

# Функция для сканирования директорий
scan_directories() {
  local name=$1
  local url=$2
  
  echo "=== Сканирование директорий $name с помощью dirb ==="
  dirb "$url" /usr/share/dirb/wordlists/common.txt -o "$RESULTS_DIR/dirb-$name.txt" -r
  echo "Результаты сохранены в $RESULTS_DIR/dirb-$name.txt"
}

# Функция для сканирования с помощью OWASP ZAP (если установлен)
scan_with_zap() {
  local name=$1
  local url=$2
  
  if command -v zap > /dev/null; then
    echo "=== Сканирование $name с помощью OWASP ZAP ==="
    zap -cmd -silent -quickurl "$url" -quickout "$RESULTS_DIR/zap-$name.html"
    echo "Результаты сохранены в $RESULTS_DIR/zap-$name.html"
  else
    echo "OWASP ZAP не установлен или не найден в PATH"
  fi
}

# Выполнение сканирования для каждого целевого компонента
for name in "${!targets[@]}"; do
  url="${targets[$name]}"
  echo -e "\n=== Начало сканирования для $name ($url) ==="
  
  # Проверка доступности компонента
  if curl -s -I "$url" | grep -q "200 OK"; then
    echo "$name доступен для сканирования"
    
    # Выполнение сканирований для компонента
    scan_with_nikto "$name" "$url"
    scan_ssl "$name" "$url"
    scan_with_nmap "$name" "$url"
    scan_directories "$name" "$url"
    scan_with_zap "$name" "$url"
  else
    echo "Сервис $name недоступен, сканирование пропущено"
  fi
done

echo "Автоматизированное комплексное сканирование безопасности завершено"
echo "Все результаты сохранены в $RESULTS_DIR"
EOF

chmod +x /tmp/automated-security-scan.sh
```

#### 10.8.2. Пентестинг и проверка защиты от социальной инженерии

Для полного тестирования безопасности системы рекомендуется провести пентестинг с привлечением специалистов в области информационной безопасности. Однако, вы можете выполнить базовую проверку защиты от социальной инженерии:

```bash
# Скрипт для базовой проверки защиты от социальной инженерии
# Сохранить скрипт в постоянную директорию
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/social-engineering-check.sh << 'EOF'
#!/bin/bash

echo "Базовая проверка защиты от социальной инженерии..."

# Создание отчета о потенциальных рисках
echo "=== Отчет о потенциальных рисках социальной инженерии ===" > /tmp/social-engineering-report.txt

# Проверка наличия политик безопасности
echo -e "\n=== Проверка наличия документированных политик безопасности ===" >> /tmp/social-engineering-report.txt
if [ -f "/path/to/security-policy.pdf" ]; then
  echo "Политика безопасности найдена: /path/to/security-policy.pdf" >> /tmp/social-engineering-report.txt
else
  echo "ВНИМАНИЕ: Документированная политика безопасности не найдена" >> /tmp/social-engineering-report.txt
  echo "Рекомендуется создать и распространить политику безопасности, включающую:" >> /tmp/social-engineering-report.txt
  echo "- Правила обращения с конфиденциальной информацией" >> /tmp/social-engineering-report.txt
  echo "- Протоколы реагирования на потенциальные атаки социальной инженерии" >> /tmp/social-engineering-report.txt
  echo "- Процедуры проверки личности при запросе чувствительной информации" >> /tmp/social-engineering-report.txt
fi

# Проверка наличия обучения по информационной безопасности
echo -e "\n=== Проверка наличия обучения по информационной безопасности ===" >> /tmp/social-engineering-report.txt
echo "Рекомендуется проводить регулярное обучение персонала по следующим темам:" >> /tmp/social-engineering-report.txt
echo "- Распознавание попыток фишинга" >> /tmp/social-engineering-report.txt
echo "- Безопасное обращение с учетными данными" >> /tmp/social-engineering-report.txt
echo "- Защита от манипуляций и социальной инженерии" >> /tmp/social-engineering-report.txt
echo "- Проверка личности запрашивающих чувствительную информацию" >> /tmp/social-engineering-report.txt

# Проверка учетных записей администраторов
echo -e "\n=== Проверка учетных записей администраторов ===" >> /tmp/social-engineering-report.txt
# WordPress
echo "WordPress:" >> /tmp/social-engineering-report.txt
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user_login FROM $MYSQL_DATABASE.wp_users WHERE ID IN (SELECT user_id FROM $MYSQL_DATABASE.wp_usermeta WHERE meta_key = 'wp_capabilities' AND meta_value LIKE '%administrator%');" | grep -v "user_login" >> /tmp/social-engineering-report.txt

# n8n
echo "n8n:" >> /tmp/social-engineering-report.txt
echo "ПРОВЕРИТЬ: Учетные записи администраторов в n8n" >> /tmp/social-engineering-report.txt

# Рекомендации по защите
echo -e "\n=== Рекомендации по защите от социальной инженерии ===" >> /tmp/social-engineering-report.txt
echo "1. Внедрить многофакторную аутентификацию для всех административных интерфейсов" >> /tmp/social-engineering-report.txt
echo "2. Регулярно обновлять и усложнять пароли всех учетных записей" >> /tmp/social-engineering-report.txt
echo "3. Проводить периодические тренинги по информационной безопасности для всех сотрудников" >> /tmp/social-engineering-report.txt
echo "4. Внедрить процедуру проверки личности при запросе чувствительной информации или изменении учетных данных" >> /tmp/social-engineering-report.txt
echo "5. Документировать и регулярно обновлять политики информационной безопасности" >> /tmp/social-engineering-report.txt

echo "Отчет о базовой проверке защиты от социальной инженерии сохранен в /tmp/social-engineering-report.txt"
EOF

chmod +x /tmp/social-engineering-check.sh
```
