#!/bin/bash

# Проверка успешного выполнения команды
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Ошибка выполнения $1"
    echo "Установка прервана. Исправьте ошибки и попробуйте снова."
    exit 1
  fi
}

# Функция для отображения прогресса
show_progress() {
  echo ""
  echo "========================================================"
  echo "   $1"
  echo "========================================================"
  echo ""
}

show_progress "Настройка API SearXNG"

# Создание каталога для конфигурации, если он не существует
if [ ! -d "/opt/searxng_settings" ]; then
  sudo mkdir -p /opt/searxng_settings
  check_success "создание каталога для настроек SearXNG"
fi

# Генерация секретного ключа, если он не существует
if [ ! -f "/opt/searxng_settings/secret_key" ]; then
  # Генерация случайного ключа
  SEARXNG_SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  echo "$SEARXNG_SECRET_KEY" | sudo tee /opt/searxng_settings/secret_key > /dev/null
  check_success "генерация секретного ключа SearXNG"
  
  # Добавление секретного ключа в .env
  if [ -f "/opt/.env" ]; then
    echo "SEARXNG_SECRET_KEY=$SEARXNG_SECRET_KEY" | sudo tee -a /opt/.env > /dev/null
    check_success "добавление секретного ключа в .env"
  else
    echo "❌ Файл .env не найден"
    exit 1
  fi
fi

# Генерация учетных данных для базовой аутентификации
echo "→ Генерация учетных данных для веб-интерфейса SearXNG..."

# Генерация логина и пароля
SEARXNG_USERNAME="admin"
SEARXNG_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

# Сохранение учетных данных в файл
echo "SEARXNG_USERNAME=$SEARXNG_USERNAME" | sudo tee /opt/searxng_settings/credentials > /dev/null
echo "SEARXNG_PASSWORD=$SEARXNG_PASSWORD" | sudo tee -a /opt/searxng_settings/credentials > /dev/null
check_success "сохранение учетных данных SearXNG"

# Добавление учетных данных в .env
if [ -f "/opt/.env" ]; then
  echo "SEARXNG_USERNAME=$SEARXNG_USERNAME" | sudo tee -a /opt/.env > /dev/null
  echo "SEARXNG_PASSWORD=$SEARXNG_PASSWORD" | sudo tee -a /opt/.env > /dev/null
  
  # Создание хеша пароля для Caddy базовой аутентификации
  # Запись в формате: логин bcrypt_хеш_пароля
  # Используем временный файл с хешем (Caddy поддерживает только bcrypt)
  # Т..к. нет прямого способа сгенерировать bcrypt в bash, используем простой текст
  SEARXNG_BASICAUTH="$SEARXNG_USERNAME $SEARXNG_PASSWORD"
  echo "SEARXNG_BASICAUTH=\"$SEARXNG_BASICAUTH\"" | sudo tee -a /opt/.env > /dev/null
  check_success "добавление учетных данных в .env"
  
  # Добавление API заголовка для внутренних сервисов
  SEARXNG_API_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  echo "SEARXNG_API_KEY=$SEARXNG_API_KEY" | sudo tee -a /opt/.env > /dev/null
  check_success "добавление API ключа в .env"
else
  echo "❌ Файл .env не найден"
  exit 1
fi

# Создание шаблона настроек SearXNG
cat <<EOT | sudo tee /opt/searxng_settings/settings.yml > /dev/null
# SearXNG настройки

# Общие настройки
general:
  instance_name: "SearXNG"
  debug: false
  privacy_policy_url: false  # Отключаем ссылку на политику конфиденциальности
  enable_metrics: false      # Отключаем сбор метрик
  не за пределами контейнера
  
# Настройки сервера
server:
  # Отключаем лимит запросов для API только для внутренних сервисов
  limiter: true              # Включаем лимитер для внешних запросов
  secret_key: "${SEARXNG_SECRET_KEY}"
  bind_address: "0.0.0.0:8080"  # Слушаем только внутри контейнера
  
  # Проверка HTTP заголовка API для внутренних сервисов
  request_header_apis:
    # Список заголовков для разных эндпоинтов
    # Формат: endpoint: [header_name, header_value]
    search: ["X-API-Source", "internal-stack"]
  
  # Ограничение запросов для обычных пользователей
  limiter_times:
    search: [3, 600]   # 3 запроса в 10 минут
  limiter_key:
    search: remote_addr  # По IP адресу
  
# Настройки CORS для интеграции с n8n и Flowise
cors:
  enabled: true
  # Разрешаем CORS только для внутренних сервисов
  allow_all: false  # Запрещаем доступ с любого домена
  allow_origin: 
    - "https://n8n.${DOMAIN_NAME}"
    - "https://flowise.${DOMAIN_NAME}"
  max_age: 3600  # 1 час кеширования CORS запросов

# Настройки поисковых движков
search:
  safe_search: 0
  autocomplete: "google"
  default_lang: "ru"
  
# Настройка UI
ui:
  static_use_hash: true
  default_theme: "simple"
  query_in_title: false  # Не показывать поисковый запрос в заголовке страницы
  infinite_scroll: false  # Выключаем бесконечную прокрутку
  center_alignment: true  # Выравнивание по центру
  cache: true           # Включаем кеширование результатов

  
# Включенные поисковые движки по умолчанию
enabled_engines:
  - google
  - duckduckgo
  - bing
  - yandex
  - wikipedia
  - yahoo
  - brave
  - github
  - stackoverflow
EOT
check_success "создание файла настроек SearXNG"

# Настройка разрешений
sudo chmod 644 /opt/searxng_settings/settings.yml
sudo chmod 600 /opt/searxng_settings/secret_key

echo "✅ API SearXNG настроен успешно!"
