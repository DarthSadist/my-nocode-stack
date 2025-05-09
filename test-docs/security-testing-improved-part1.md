# Руководство по тестированию безопасности стека (Часть 1)

> **Примечание:** Нумерация разделов соответствует общему плану тестирования, где раздел 10 посвящен проверке безопасности.

## 10. Проверка безопасности

Безопасность является критически важным аспектом любой системы, особенно когда речь идет о многокомпонентном стеке с различными веб-сервисами и базами данных. Комплексное тестирование безопасности позволяет выявить уязвимости и обеспечить защиту от потенциальных угроз.

### 10.1. Подготовка к проверке безопасности

#### 10.1.1. Инвентаризация компонентов и сервисов

Прежде чем приступить к тестированию безопасности, необходимо провести инвентаризацию всех компонентов системы и определить поверхность атаки.

```bash
# Скрипт для инвентаризации компонентов стека
# Сохранить этот скрипт в постоянную директорию для дальнейшего использования
# mkdir -p ~/my-nocode-stack/test-scripts/security
# cat > ~/my-nocode-stack/test-scripts/security/security-inventory.sh << 'EOF'
#!/bin/bash

echo "Инвентаризация компонентов стека для анализа безопасности..."

# Функция для форматированного вывода
print_header() {
  echo -e "\n=== $1 ==="
}

# Список запущенных контейнеров
print_header "Запущенные контейнеры"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"

# Анализ сетевых подключений
print_header "Открытые порты и сетевые подключения"
docker network ls
docker network inspect stack_default | jq '.[] | .Containers'
netstat -tulpn | grep LISTEN

# Список используемых образов и их версии
print_header "Используемые образы Docker"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}"

# Анализ установленных сервисов внутри контейнеров
print_header "Установленные сервисы и их версии"
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker exec $container bash -c '(command -v apt && apt list --installed 2>/dev/null) || 
                                 (command -v apk && apk info) || 
                                 (command -v rpm && rpm -qa) || 
                                 echo "Неизвестная система управления пакетами"' 2>/dev/null | grep -i "server\|nginx\|apache\|mysql\|postgres\|php\|python\|node\|npm"
done

# Проверка наличия файлов с чувствительной информацией
print_header "Файлы с потенциально чувствительной информацией"
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker exec $container find / -name "*.env" -o -name "*.config" -o -name "*.yml" -o -name "*.yaml" -o -name "*.ini" -o -name "*.conf" 2>/dev/null | grep -v "node_modules\|proc" | head -20
done

# Анализ переменных окружения
print_header "Анализ переменных окружения"
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  echo "--- $container ---"
  docker exec $container env 2>/dev/null | grep -v "PATH\|PWD\|HOME\|HOSTNAME" | grep -i "key\|pass\|secret\|token\|auth" | sed 's/\(pass\|key\|secret\|token\).*=.*/\1*** = <СКРЫТО>/'
done

echo "Инвентаризация завершена. Результаты могут быть использованы для планирования тестирования безопасности."
EOF

chmod +x /tmp/security-inventory.sh
```

#### 10.1.2. Установка инструментов для проверки безопасности

Для проведения тестирования безопасности потребуются специализированные инструменты:

```bash
# Установка базовых инструментов для тестирования безопасности
apt-get update && apt-get install -y \
  nmap \
  nikto \
  wapiti \
  sqlmap \
  dirb \
  hydra \
  sslscan \
  gobuster \
  whatweb \
  john

# Установка OWASP ZAP (автоматизированный сканер безопасности)
wget -q https://github.com/zaproxy/zaproxy/releases/download/v2.13.0/ZAP_2.13.0_Linux.tar.gz -O /tmp/zap.tar.gz
tar -xzf /tmp/zap.tar.gz -C /opt
ln -s /opt/ZAP_2.13.0/zap.sh /usr/local/bin/zap
```

**Описание основных инструментов:**
- **nmap**: Сканер портов и сервисов
- **nikto**: Сканер веб-уязвимостей
- **wapiti**: Сканер веб-приложений для выявления уязвимостей
- **sqlmap**: Инструмент для тестирования SQL-инъекций
- **dirb/gobuster**: Инструменты для поиска директорий и файлов на веб-серверах
- **hydra**: Инструмент для тестирования атак по словарю
- **sslscan**: Инструмент для анализа SSL/TLS
- **whatweb**: Инструмент для определения используемых технологий на веб-сайте
- **OWASP ZAP**: Комплексный сканер веб-уязвимостей

### 10.2. Проверка конфигурации безопасности

#### 10.2.1. Аудит конфигурации Docker

```bash
# Скрипт для аудита безопасности Docker
cat > /tmp/docker-security-audit.sh << 'EOF'
#!/bin/bash

echo "Аудит безопасности Docker..."

# Проверка версии Docker
echo "=== Версия Docker ==="
docker version
docker info

# Проверка конфигурации демона Docker
echo -e "\n=== Конфигурация демона Docker ==="
cat /etc/docker/daemon.json 2>/dev/null || echo "Файл daemon.json не найден"

# Проверка настроек сети
echo -e "\n=== Настройки сети Docker ==="
docker network ls
docker network inspect bridge | jq '.'

# Проверка прав доступа к сокету Docker
echo -e "\n=== Права доступа к сокету Docker ==="
ls -la /var/run/docker.sock

# Проверка списка пользователей с доступом к Docker
echo -e "\n=== Пользователи с доступом к Docker ==="
getent group docker

# Проверка образов на наличие уязвимостей (если установлен trivy)
echo -e "\n=== Проверка образов на уязвимости ==="
if command -v trivy &> /dev/null; then
  for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
    echo "Проверка образа: $image"
    trivy image --severity HIGH,CRITICAL $image
  done
else
  echo "Trivy не установлен. Установите trivy для сканирования образов."
fi

# Проверка контейнеров на правильность настроек безопасности
echo -e "\n=== Проверка настроек безопасности контейнеров ==="
for container in $(docker ps -q); do
  name=$(docker inspect --format '{{.Name}}' $container | sed 's/\///')
  echo "--- Контейнер: $name ---"
  
  # Проверка привилегированного режима
  privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' $container)
  echo "Привилегированный режим: $privileged"
  
  # Проверка монтирования чувствительных путей
  mounts=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' $container)
  echo "Монтированные пути: $mounts"
  
  # Проверка использования capabilities
  caps=$(docker inspect --format '{{.HostConfig.CapAdd}}' $container)
  echo "Дополнительные capabilities: $caps"
  
  # Проверка пользователя, от имени которого запущен контейнер
  user=$(docker inspect --format '{{.Config.User}}' $container)
  echo "Пользователь: ${user:-root}"
done

echo "Аудит безопасности Docker завершен"
EOF

chmod +x /tmp/docker-security-audit.sh
```

#### 10.2.2. Проверка настроек конфигурации компонентов

```bash
# Скрипт для проверки конфигурации компонентов
cat > /tmp/components-security-audit.sh << 'EOF'
#!/bin/bash

echo "Аудит безопасности конфигурации компонентов..."

# Функция для проверки настроек PostgreSQL
check_postgres_security() {
  echo "=== Аудит безопасности PostgreSQL ==="
  
  # Проверка настроек аутентификации
  docker exec postgres grep -E "host|local" /var/lib/postgresql/data/pg_hba.conf
  
  # Проверка настроек SSL
  docker exec postgres psql -U $POSTGRES_USER -c "SHOW ssl;"
  
  # Проверка прав пользователей
  docker exec postgres psql -U $POSTGRES_USER -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb FROM pg_roles;"
  
  # Проверка открытых соединений
  docker exec postgres psql -U $POSTGRES_USER -c "SELECT * FROM pg_stat_activity;"
}

# Функция для проверки настроек MariaDB
check_mariadb_security() {
  echo -e "\n=== Аудит безопасности MariaDB ==="
  
  # Проверка наличия анонимных пользователей
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT User, Host FROM mysql.user WHERE User='';"
  
  # Проверка пользователей с привилегиями
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT User, Host, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv, Super_priv FROM mysql.user;"
  
  # Проверка настроек безопасности
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE '%secure%';"
}

# Функция для проверки настроек Redis
check_redis_security() {
  echo -e "\n=== Аудит безопасности Redis ==="
  
  # Проверка наличия пароля
  docker exec redis redis-cli CONFIG GET requirepass
  
  # Проверка привязки к сетевым интерфейсам
  docker exec redis redis-cli CONFIG GET bind
  
  # Проверка защищенного режима
  docker exec redis redis-cli CONFIG GET protected-mode
}

# Функция для проверки настроек WordPress
check_wordpress_security() {
  echo -e "\n=== Аудит безопасности WordPress ==="
  
  # Проверка версии WordPress
  docker exec wordpress wp core version --path=/var/www/html 2>/dev/null || echo "WP-CLI не установлен"
  
  # Проверка настроек безопасности в wp-config.php
  docker exec wordpress grep -E "AUTH_KEY|SECURE_AUTH_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|NONCE_SALT" /var/www/html/wp-config.php | wc -l
  
  # Проверка наличия админов
  docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ID, user_login, user_pass FROM $MYSQL_DATABASE.wp_users WHERE user_login = 'admin';"
  
  # Проверка директорий и файлов на права доступа
  docker exec wordpress find /var/www/html -type f -name "*.php" -perm /o+w | wc -l
}

# Функция для проверки настроек n8n
check_n8n_security() {
  echo -e "\n=== Аудит безопасности n8n ==="
  
  # Проверка наличия ключа шифрования
  docker exec n8n bash -c 'env | grep N8N_ENCRYPTION_KEY'
  
  # Проверка настроек безопасности для Webhook
  docker exec n8n bash -c 'env | grep N8N_WEBHOOK'
  
  # Проверка наличия пользовательского управления
  docker exec n8n bash -c 'env | grep N8N_USER_MANAGEMENT'
}

# Выполнение проверок для каждого компонента
check_postgres_security
check_mariadb_security
check_redis_security
check_wordpress_security
check_n8n_security

echo "Аудит безопасности конфигурации компонентов завершен"
EOF

chmod +x /tmp/components-security-audit.sh
```

#### 10.2.3. Проверка обновлений и патчей безопасности

```bash
# Скрипт для проверки актуальности версий и наличия патчей безопасности
cat > /tmp/check-security-updates.sh << 'EOF'
#!/bin/bash

echo "Проверка наличия обновлений безопасности..."

# Функция для проверки образов на наличие обновлений
check_image_updates() {
  echo "=== Проверка обновлений образов Docker ==="
  
  for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
    echo "Проверка образа: $image"
    latest_digest=$(docker pull $image 2>/dev/null | grep "Digest:")
    current_digest=$(docker images --digests --format "{{.Digest}}" --filter "reference=$image")
    
    if [ "$latest_digest" != "$current_digest" ]; then
      echo "Доступно обновление для образа $image"
    else
      echo "Образ $image актуален"
    fi
  done
}

# Функция для проверки безопасности WordPress
check_wordpress_security_updates() {
  echo -e "\n=== Проверка обновлений безопасности WordPress ==="
  
  # Проверка основных обновлений
  docker exec wordpress wp core check-update --path=/var/www/html 2>/dev/null || echo "WP-CLI не установлен"
  
  # Проверка обновлений плагинов
  docker exec wordpress wp plugin list --path=/var/www/html 2>/dev/null || echo "WP-CLI не установлен"
  
  # Проверка обновлений тем
  docker exec wordpress wp theme list --path=/var/www/html 2>/dev/null || echo "WP-CLI не установлен"
}

# Функция для проверки уязвимостей в базе CVE
check_cve_vulnerabilities() {
  echo -e "\n=== Проверка известных уязвимостей в компонентах ==="
  
  # Проверка PostgreSQL
  pg_version=$(docker exec postgres psql -U $POSTGRES_USER -c "SELECT version();" | grep -o "PostgreSQL [0-9.]*")
  echo "PostgreSQL: $pg_version"
  
  # Проверка MariaDB
  mariadb_version=$(docker exec mariadb mysql -V | grep -o "Distrib [0-9.]*")
  echo "MariaDB: $mariadb_version"
  
  # Проверка Redis
  redis_version=$(docker exec redis redis-cli info | grep redis_version)
  echo "Redis: $redis_version"
  
  # Проверка n8n
  n8n_version=$(docker exec n8n n8n --version 2>/dev/null || echo "Невозможно определить версию n8n")
  echo "n8n: $n8n_version"
  
  # Проверка WordPress
  wp_version=$(docker exec wordpress wp core version --path=/var/www/html 2>/dev/null || echo "Невозможно определить версию WordPress")
  echo "WordPress: $wp_version"
}

# Выполнение проверок
check_image_updates
check_wordpress_security_updates
check_cve_vulnerabilities

echo "Проверка наличия обновлений безопасности завершена"
EOF

chmod +x /tmp/check-security-updates.sh
```

### 10.3. Проверка сетевой безопасности

#### 10.3.1. Сканирование портов и сервисов

```bash
# Скрипт для сканирования портов и сервисов
cat > /tmp/network-security-scan.sh << 'EOF'
#!/bin/bash

echo "Сканирование сетевой безопасности..."

# Определение целевых хостов (localhost и контейнеры в сети Docker)
HOST_IP=$(hostname -I | awk '{print $1}')
DOCKER_SUBNET=$(docker network inspect bridge | grep Subnet | awk '{print $2}' | tr -d '",')

# Базовое сканирование портов localhost
echo "=== Сканирование портов на localhost ==="
nmap -sS -sV -p 1-65535 localhost

# Сканирование хоста
echo -e "\n=== Сканирование портов на основном хосте ($HOST_IP) ==="
nmap -sS -sV $HOST_IP

# Сканирование сети Docker
echo -e "\n=== Сканирование сети Docker ($DOCKER_SUBNET) ==="
nmap -sS -sV $DOCKER_SUBNET

# Детальное сканирование веб-сервисов
echo -e "\n=== Детальное сканирование веб-сервисов ==="
for port in 80 443 5678 3000 3001 8080; do
  echo "Сканирование порта $port"
  nmap -sV -p $port --script=http-enum,http-headers,http-methods,http-title $HOST_IP
done

# Проверка SSL/TLS конфигурации
echo -e "\n=== Проверка SSL/TLS конфигурации ==="
for domain in localhost n8n.example.com flowise.example.com wordpress.example.com; do
  echo "Проверка SSL для $domain"
  sslscan --no-failed $domain:443 2>/dev/null || echo "Не удалось выполнить проверку SSL для $domain"
done

# Проверка открытых портов контейнеров
echo -e "\n=== Проверка открытых портов контейнеров ==="
for container in n8n flowise postgres redis qdrant wordpress mariadb; do
  container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container)
  echo "Контейнер: $container ($container_ip)"
  nmap -sS -p- $container_ip
done

echo "Сканирование сетевой безопасности завершено"
EOF

chmod +x /tmp/network-security-scan.sh
```

#### 10.3.2. Проверка доступности сервисов извне

```bash
# Скрипт для проверки доступности сервисов извне
cat > /tmp/external-access-check.sh << 'EOF'
#!/bin/bash

echo "Проверка доступности сервисов извне..."

# Получение внешнего IP-адреса
EXTERNAL_IP=$(curl -s https://ipinfo.io/ip)
echo "Внешний IP-адрес: $EXTERNAL_IP"

# Проверка открытых портов с внешнего сервиса
echo "=== Проверка открытых портов с внешнего сервиса ==="
curl -s https://api.hackertarget.com/nmap/?q=$EXTERNAL_IP

# Проверка настроек брандмауэра
echo -e "\n=== Настройки брандмауэра ==="
if command -v ufw > /dev/null; then
  ufw status verbose
elif command -v firewall-cmd > /dev/null; then
  firewall-cmd --list-all
elif command -v iptables > /dev/null; then
  iptables -L -n
else
  echo "Не удалось определить тип брандмауэра"
fi

# Проверка правил Docker для портов
echo -e "\n=== Правила Docker для портов ==="
docker ps --format "{{.Names}}: {{.Ports}}"

# Проверка настроек Caddy или другого прокси
echo -e "\n=== Настройки прокси ==="
if [ -f /etc/caddy/Caddyfile ]; then
  echo "Файл Caddyfile найден:"
  cat /etc/caddy/Caddyfile
else
  echo "Файл Caddyfile не найден"
fi

echo "Проверка доступности сервисов извне завершена"
EOF

chmod +x /tmp/external-access-check.sh
```
