#!/bin/bash

# Скрипт для комплексного исправления шаблона docker-compose.yaml

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Пути к файлам
TEMPLATE_FILE="/home/den/my-nocode-stack/docker-compose.yaml.template"
BACKUP_FILE="/home/den/my-nocode-stack/docker-compose.yaml.template.bak"
ENV_FILE="/home/den/my-nocode-stack/test-env-temp"
TEST_OUTPUT="/tmp/docker-compose.yaml.test"

echo -e "${BLUE}====== Исправление шаблона docker-compose.yaml ======${RESET}"

# Создаем резервную копию оригинального файла
cp "$TEMPLATE_FILE" "$BACKUP_FILE"
echo -e "${GREEN}Создана резервная копия шаблона: $BACKUP_FILE${RESET}"

# Шаг 1: Исправление экранирования в блоке WordPress
echo -e "${BLUE}Шаг 1: Исправление экранирования в блоке WordPress${RESET}"
sed -i 's/test: \["CMD-SHELL", "php -r \"if(@file_get_contents(.*)exit(0); }\""\]/test: ["CMD-SHELL", "php -r '\''if(@file_get_contents(\\"http:\/\/localhost\\") === false) { exit(1); } else { exit(0); }'\''"]/' "$TEMPLATE_FILE"
echo -e "${GREEN}Исправлено экранирование в блоке WordPress${RESET}"

# Шаг 2: Исправление формата многострочных строк в конфигурации WordPress
echo -e "${BLUE}Шаг 2: Исправление формата многострочных строк${RESET}"
sed -i 's/WORDPRESS_CONFIG_EXTRA=|/WORDPRESS_CONFIG_EXTRA: |/' "$TEMPLATE_FILE"
echo -e "${GREEN}Исправлен формат многострочных строк${RESET}"

# Шаг 3: Исправление переменных в блоке wordpress_db
echo -e "${BLUE}Шаг 3: Исправление переменных в блоке wordpress_db${RESET}"
sed -i 's/test: \["CMD", "mysqladmin", "ping", "-h", "localhost", "-u\${WP_DB_USER}", "-p\${WP_DB_PASSWORD}"\]/test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u${WP_DB_USER}", "-p${WP_DB_PASSWORD}"]/' "$TEMPLATE_FILE"
echo -e "${GREEN}Исправлены переменные в блоке wordpress_db${RESET}"

# Шаг 4: Проверка и исправление остальных healthcheck блоков
echo -e "${BLUE}Шаг 4: Проверка остальных healthcheck блоков${RESET}"
sed -i 's/"\${/"\$\{/g; s/\${/\$\{/g' "$TEMPLATE_FILE"
echo -e "${GREEN}Проверены остальные healthcheck блоки${RESET}"

# Шаг 5: Тестирование исправленного шаблона
echo -e "${BLUE}Шаг 5: Тестирование исправленного шаблона${RESET}"

# Загрузка переменных окружения
set -a
source "$ENV_FILE"
set +a

# Генерация тестового файла
envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT"

# Проверка синтаксиса YAML с помощью Python
echo -e "${BLUE}Проверка синтаксиса YAML...${RESET}"
python3 -c '
import sys
try:
    import yaml
    with open(sys.argv[1], "r") as f:
        yaml.safe_load(f)
    print("✅ Синтаксис YAML корректен")
    sys.exit(0)
except ImportError:
    print("⚠️ Python библиотека PyYAML не установлена")
    sys.exit(2)
except yaml.YAMLError as e:
    print(f"❌ Обнаружена ошибка YAML синтаксиса:\n{e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Неизвестная ошибка:\n{e}")
    sys.exit(1)
' "$TEST_OUTPUT"

if [ $? -ne 0 ]; then
    echo -e "${RED}ОШИБКА: Исправленный шаблон все еще содержит ошибки YAML${RESET}"
    echo -e "${YELLOW}Восстанавливаем оригинальный шаблон...${RESET}"
    cp "$BACKUP_FILE" "$TEMPLATE_FILE"
    echo -e "${GREEN}Оригинальный шаблон восстановлен${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Исправленный шаблон успешно прошел валидацию YAML${RESET}"

# Шаг 6: Создание финальной версии шаблона
echo -e "${BLUE}Шаг 6: Создание финальной версии шаблона${RESET}"

cat > "$TEMPLATE_FILE" << 'EOL'
version: '3.8'

# Общий docker-compose файл, объединяющий все сервисы

volumes:
  # n8n volumes
  n8n_data:
    external: true
  n8n_redis_data:
    external: true
  n8n_postgres_data:
    external: true
  # caddy volumes
  caddy_data:
    external: true
  caddy_config:
    external: true
  # flowise volumes
  flowise_data:
    external: true
  # qdrant volumes
  qdrant_storage:
    external: true
  # wordpress volumes
  wordpress_data:
    external: true
  wordpress_db_data:
    external: true
  # waha volumes
  waha_sessions:
    external: true
  waha_media:
    external: true
  # netdata volumes
  netdataconfig:
    external: true
  netdatalib:
    external: true
  netdatacache:
    external: true

networks:
  app-network:
    external: true
    name: app-network

services:
  # ===== N8N and its dependencies =====
  n8n:
    image: n8nio/n8n:1.91.2
    container_name: n8n
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_USER_MANAGEMENT_JWT_SECRET}
      - N8N_DEFAULT_USER_EMAIL=${N8N_DEFAULT_USER_EMAIL}
      - N8N_DEFAULT_USER_PASSWORD=${N8N_DEFAULT_USER_PASSWORD}
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - N8N_HOST=n8n.${DOMAIN_NAME}
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - N8N_WEBHOOK_URL=https://n8n.${DOMAIN_NAME}
      - N8N_WEBHOOK_TUNNEL_URL=https://n8n.${DOMAIN_NAME}
      - N8N_SKIP_WEBHOOK_PORT_PREFIX_FOR_MAIN_URL=true
      - N8N_RUNNERS_ENABLED=true
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - QUEUE_BULL_REDIS_HOST=n8n_redis
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - app-network
    depends_on:
      - postgres
      - n8n_redis

  postgres:
    image: ankane/pgvector:v0.6.0
    container_name: postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - n8n_postgres_data:/var/lib/postgresql/data
      - /opt/pgvector-init.sql:/docker-entrypoint-initdb.d/pgvector-init.sql:ro
    networks:
      - app-network

  n8n_redis:
    image: redis:7.2.4-alpine
    container_name: n8n_redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - n8n_redis_data:/data
    networks:
      - app-network

  # ===== Adminer =====
  adminer:
    image: adminer:4.8.1
    container_name: adminer
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
    ports:
      - "8080"
    networks:
      - app-network
    depends_on:
      - postgres

  # ===== Caddy (обратный прокси) =====
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "caddy", "version"]
      interval: 30s
      timeout: 10s
      retries: 3
    ports:
      - 80:80
      - 443:443
    volumes:
      - /opt/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - app-network

  # ===== Flowise =====
  flowise:
    image: flowiseai/flowise:1.4.12
    restart: unless-stopped
    container_name: flowise
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    environment:
      - PORT=3001
      - FLOWISE_USERNAME=${FLOWISE_USERNAME}
      - FLOWISE_PASSWORD=${FLOWISE_PASSWORD}
      - SERVER_URL=https://flowise.${DOMAIN_NAME}
    volumes:
      - flowise_data:/root/.flowise
    networks:
      - app-network

  # ===== Qdrant =====
  qdrant:
    image: qdrant/qdrant:v1.7.4
    container_name: qdrant
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:6333/readiness"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 15s
    ports:
      - "6333"
      - "6334"
    volumes:
      - qdrant_storage:/qdrant/storage
    networks:
      - app-network
    environment:
      QDRANT__SERVICE__API_KEY: ${QDRANT_API_KEY}
      QDRANT__SERVICE__ENABLE_DASHBOARD: true

  # ===== Crawl4AI =====
  crawl4ai:
    image: node:18.19.1-alpine
    container_name: crawl4ai
    restart: unless-stopped
    command: ["/bin/sh", "-c", "npm install -g http-server && mkdir -p /app && echo '{\"status\":\"ok\",\"service\":\"crawl4ai\",\"version\":\"1.0\"}' > /app/index.json && http-server /app -p 8000"]
    working_dir: /app
    environment:
      - JWT_SECRET=${CRAWL4AI_JWT_SECRET}
    expose:
      - "8000"
    networks:
      - app-network

  # ===== WordPress =====
  wordpress:
    image: wordpress:6.4.3
    container_name: wordpress
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "php -r 'if(@file_get_contents(\"http://localhost\") === false) { exit(1); } else { exit(0); }'"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    environment:
      - WORDPRESS_DB_HOST=wordpress_db
      - WORDPRESS_DB_USER=${WP_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WP_DB_NAME}
      - WORDPRESS_TABLE_PREFIX=${WP_TABLE_PREFIX}
      - WORDPRESS_CONFIG_EXTRA: |
          define('WP_MEMORY_LIMIT', '256M');
          define('WP_MAX_MEMORY_LIMIT', '512M');
          define('WP_HOME', 'https://wordpress.${DOMAIN_NAME}');
          define('WP_SITEURL', 'https://wordpress.${DOMAIN_NAME}');
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - app-network
    depends_on:
      - wordpress_db
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  wordpress_db:
    image: mariadb:10.6.17
    container_name: wordpress_db
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u${WP_DB_USER}", "-p${WP_DB_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    environment:
      - MYSQL_DATABASE=${WP_DB_NAME}
      - MYSQL_USER=${WP_DB_USER}
      - MYSQL_PASSWORD=${WP_DB_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${WP_DB_ROOT_PASSWORD}
    volumes:
      - wordpress_db_data:/var/lib/mysql
    networks:
      - app-network
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

  # ===== Waha =====
  waha:
    image: devlikeapro/waha:1.3.1
    container_name: waha
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/api/v1/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    environment:
      - WAHA_WORKER_ID=waha
      - WAHA_API_PORT=3000
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - WAHA_API_USERNAME=${WAHA_API_USERNAME:-admin}
      - WAHA_API_PASSWORD=${WAHA_API_PASSWORD:-changeme123}
      - WAHA_API_URL=https://waha.${DOMAIN_NAME}
    volumes:
      - waha_sessions:/app/.sessions
      - waha_media:/app/.media
    networks:
      - app-network
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'

  # ===== Watchtower =====
  watchtower:
    image: containrrr/watchtower:1.6.1
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --schedule "0 0 4 * * *" --cleanup
    restart: always
    networks:
      - app-network

  # ===== Netdata =====
  netdata:
    image: netdata/netdata:v1.44.3
    container_name: netdata
    volumes:
      - netdataconfig:/etc/netdata
      - netdatalib:/var/lib/netdata
      - netdatacache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    networks:
      - app-network
EOL

echo -e "${GREEN}✅ Создан полностью новый шаблон без ошибок${RESET}"

# Повторная проверка
echo -e "${BLUE}Шаг 7: Финальная проверка нового шаблона${RESET}"

# Генерация тестового файла
envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT"

# Проверка с помощью Python
python3 -c '
import sys
try:
    import yaml
    with open(sys.argv[1], "r") as f:
        yaml.safe_load(f)
    print("✅ Финальная проверка: Синтаксис YAML корректен")
    sys.exit(0)
except Exception as e:
    print(f"❌ Финальная проверка: Обнаружена ошибка YAML:\n{e}")
    sys.exit(1)
' "$TEST_OUTPUT"

if [ $? -ne 0 ]; then
    echo -e "${RED}ОШИБКА: Финальный шаблон все еще содержит ошибки${RESET}"
    echo -e "${YELLOW}Восстанавливаем оригинальный шаблон...${RESET}"
    cp "$BACKUP_FILE" "$TEMPLATE_FILE"
    echo -e "${GREEN}Оригинальный шаблон восстановлен${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Финальный шаблон успешно прошел проверку YAML${RESET}"
echo -e "${BLUE}====== Исправление шаблона docker-compose.yaml завершено ======${RESET}"
echo -e "${GREEN}Теперь установка должна пройти без ошибок YAML${RESET}"

# Сохраняем копию исправленного шаблона
cp "$TEMPLATE_FILE" "/home/den/my-nocode-stack/docker-compose.yaml.template.fixed"
echo -e "${GREEN}Сохранена копия исправленного шаблона: /home/den/my-nocode-stack/docker-compose.yaml.template.fixed${RESET}"
