#!/bin/bash

echo -e "\n=================================================================="
echo "🚀 Запуск всех сервисов через единый docker-compose файл"
echo -e "\n=================================================================="

# Загружаем функции проверки места на диске
if [ -f "$(dirname "$0")/check_disk_space.sh" ]; then
    source "$(dirname "$0")/check_disk_space.sh"
else
    # Определяем функции проверки места на диске прямо в скрипте, если файл не найден
    check_disk_space() {
        local required_space=$1 # в MB
        local mount_point=${2:-"/"}
        
        # Получаем свободное место в KB
        local free_space=$(df -k "$mount_point" | awk 'NR==2 {print $4}')
        # Переводим в MB для удобства сравнения
        local free_space_mb=$((free_space / 1024))
        
        if [ $free_space_mb -lt $required_space ]; then
            echo "❌ Недостаточно свободного места на диске $mount_point" >&2
            echo "Требуется: $required_space MB, Доступно: $free_space_mb MB" >&2
            return 1
        else
            echo "✅ Достаточно свободного места на диске $mount_point: $free_space_mb MB"
            return 0
        fi
    }

    clean_docker_space() {
        echo "⚙️ Очистка неиспользуемых Docker ресурсов..."
        
        # Очистка неиспользуемых контейнеров
        echo "→ Удаление остановленных контейнеров..."
        sudo docker container prune -f
        
        # Очистка неиспользуемых образов
        echo "→ Удаление неиспользуемых образов..."
        sudo docker image prune -f
        
        # Очистка неиспользуемых томов
        echo "→ Удаление неиспользуемых томов..."
        sudo docker volume prune -f
        
        echo "✅ Очистка завершена. Текущее использование диска Docker:"
        sudo docker system df
    }
fi 

# Функция для проверки существования Docker-образа
check_docker_image() {
    local image=$1
    echo "📋 Проверка доступности образа: $image"
    if ! sudo docker pull $image &>/dev/null; then
        echo "❌ ОШИБКА: Образ Docker '$image' не найден или недоступен" >&2
        return 1
    else
        echo "✅ Образ '$image' успешно загружен"
        return 0
    fi
}

# Функция для проверки и исправления Caddyfile
check_and_fix_caddyfile() {
    local caddyfile="/opt/Caddyfile"
    echo -e "\n🔍 Проверка Caddyfile на наличие ошибок..."
    
    if [ ! -f "$caddyfile" ]; then
        echo "❌ ОШИБКА: Caddyfile не найден в $caddyfile" >&2
        return 1
    fi
    
    # Проверка на пустой email или неправильный формат переменной
    if grep -q "email\s*$" "$caddyfile" || grep -q "email\s*{" "$caddyfile" || grep -q "email\s*\${USER_EMAIL:-" "$caddyfile"; then
        echo "❌ ОШИБКА: Обнаружена проблема с директивой 'email' в Caddyfile" >&2
        echo "Содержимое проблемной строки:" >&2
        grep -n "email" "$caddyfile" >&2
        
        echo "⚙️ Попытка исправления Caddyfile..."
        
        # Создание резервной копии
        sudo cp "$caddyfile" "${caddyfile}.backup"
        
        # Исправление директивы email
        if grep -q "USER_EMAIL" "/opt/.env" 2>/dev/null; then
            USER_EMAIL=$(grep "USER_EMAIL" "/opt/.env" | cut -d'=' -f2)
            echo "✅ Найден email в .env файле: $USER_EMAIL"
            sudo sed -i "s/email\s*$/email $USER_EMAIL/" "$caddyfile"
            sudo sed -i "s/email\s*{/email $USER_EMAIL {/" "$caddyfile"
            sudo sed -i "s/email\s*\${USER_EMAIL:-[^}]*}/email $USER_EMAIL/" "$caddyfile"
        else
            echo "❌ Не удалось найти USER_EMAIL в .env файле" >&2
            echo "Введите email для использования в Caddyfile:"
            read -p "Email: " USER_EMAIL
            if [ -z "$USER_EMAIL" ]; then
                echo "❌ Не указан email. Используем значение по умолчанию admin@example.com" >&2
                USER_EMAIL="admin@example.com"
            fi
            sudo sed -i "s/email\s*$/email $USER_EMAIL/" "$caddyfile"
            sudo sed -i "s/email\s*{/email $USER_EMAIL {/" "$caddyfile"
            sudo sed -i "s/email\s*\${USER_EMAIL:-[^}]*}/email $USER_EMAIL/" "$caddyfile"
        fi
        
        echo "✅ Caddyfile исправлен. Создана резервная копия в ${caddyfile}.backup"
    else
        echo "✅ Директива 'email' в Caddyfile корректна"
    fi
    
    # Проверка синтаксиса Caddyfile
    echo "Проверка синтаксиса Caddyfile..."
    if ! sudo docker run --rm -v "$caddyfile:/etc/caddy/Caddyfile:ro" caddy:2 caddy validate --config /etc/caddy/Caddyfile &>/dev/null; then
        echo "❌ ОШИБКА: Caddyfile содержит синтаксические ошибки:" >&2
        sudo docker run --rm -v "$caddyfile:/etc/caddy/Caddyfile:ro" caddy:2 caddy validate --config /etc/caddy/Caddyfile
        echo "Пожалуйста, исправьте синтаксические ошибки в $caddyfile вручную" >&2
        return 1
    else
        echo "✅ Синтаксис Caddyfile корректен"
        return 0
    fi
}

# Функция для проверки и создания сети Docker
ensure_docker_network() {
  local network_name="$1"
  echo "❗ Проверка сети Docker $network_name..."
  
  if ! sudo docker network inspect "$network_name" &>/dev/null; then
    echo "❗ Сеть $network_name не существует, создаем..."
    network_id=$(sudo docker network create "$network_name" 2>/dev/null)
    if [ $? -ne 0 ]; then
      echo "❌ Ошибка: Не удалось создать сеть $network_name" >&2
      return 1
    else
      echo "✅ Сеть $network_name успешно создана"
      return 0
    fi
  else
    echo "✅ Сеть $network_name уже существует"
    return 0
  fi
}

# Проверка Docker
if ! sudo docker info > /dev/null 2>&1; then
    echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Docker не запущен" >&2
    exit 1
fi

# Путь к единому файлу docker-compose
UNIFIED_COMPOSE_FILE="/opt/docker-compose.yaml"
ENV_FILE="/opt/.env"

# Проверка существования файла docker-compose
if [ ! -f "$UNIFIED_COMPOSE_FILE" ]; then
    echo "❌ ОШИБКА: Файл $UNIFIED_COMPOSE_FILE не найден." >&2
    exit 1
fi

# Проверка существования ENV файла
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ОШИБКА: Файл $ENV_FILE не найден." >&2
    exit 1
fi

# Проверка валидности docker-compose файла
echo "Проверка валидности $UNIFIED_COMPOSE_FILE..."
sudo docker compose -f "$UNIFIED_COMPOSE_FILE" config --quiet
if [ $? -ne 0 ]; then
    echo "❌ ОШИБКА: Файл $UNIFIED_COMPOSE_FILE содержит ошибки" >&2
    echo "Пожалуйста, исправьте ошибки в $UNIFIED_COMPOSE_FILE и попробуйте снова." >&2
    exit 1
else
    echo "✅ $UNIFIED_COMPOSE_FILE валиден"
fi

# Проверка и создание сети app-network для всех сервисов
ensure_docker_network "app-network"

# Проверка и исправление Caddyfile перед запуском сервисов
echo -e "\n⚙️ Проверка конфигурации Caddy перед запуском..."
check_and_fix_caddyfile
if [ $? -ne 0 ]; then
  echo "⚠️ Обнаружены проблемы в конфигурации Caddy. Попытка продолжить установку, но сервис Caddy может работать некорректно." >&2
  read -p "Продолжить установку несмотря на ошибки? (y/n): " CONTINUE
  if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
    echo "Установка прервана пользователем." >&2
    exit 1
  fi
fi

# Проверка свободного места перед запуском
echo "Проверка свободного места перед запуском всех сервисов..."
if ! check_disk_space 2000; then # требуем минимум 2GB свободного места
  echo "⚠️ Недостаточно свободного места для запуска всех сервисов" >&2
  echo "Попытка очистки дискового пространства..." >&2
  clean_docker_space
  
  # Проверяем еще раз после очистки
  if ! check_disk_space 2000; then
    echo "❌ Критическая ошибка: Даже после очистки недостаточно места для запуска сервисов (требуется минимум 2GB)" >&2
    echo "Пожалуйста, освободите место на диске и попробуйте снова." >&2
    exit 1
  fi
fi

# Запуск всех сервисов через единый docker-compose файл
echo -e "\n===============================================" 
echo "⚡ Запуск всех сервисов через единый docker-compose файл"
echo -e "\n==============================================="
echo "Запуск сервисов (попытка 1/2)..."
sudo docker compose -f "$UNIFIED_COMPOSE_FILE" --env-file "$ENV_FILE" up -d

# Проверка результата запуска
if [ $? -ne 0 ]; then
    echo "❌ Ошибка при запуске сервисов. Повторная попытка..." >&2
    echo "Запуск сервисов (попытка 2/2)..."
    sudo docker compose -f "$UNIFIED_COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    if [ $? -ne 0 ]; then
        echo "❌ Критическая ошибка: Не удалось запустить сервисы." >&2
        echo "Попытка запуска критически важных сервисов по отдельности..."
        
        # Запуск только основных сервисов
        echo "Запуск только Caddy, PostgreSQL, Redis, n8n..."
        sudo docker compose -f "$UNIFIED_COMPOSE_FILE" --env-file "$ENV_FILE" up -d caddy postgres n8n_redis n8n
        if [ $? -ne 0 ]; then
            echo "❌ Критическая ошибка: Не удалось запустить даже основные сервисы." >&2
            exit 1
        else
            echo "✅ Основные сервисы запущены. Рекомендуется диагностировать и решить проблемы с остальными сервисами." >&2
        fi
    else
        echo "✅ Все сервисы успешно запущены со второй попытки"
    fi
else
    echo "✅ Все сервисы успешно запущены"
fi

# Ждем инициализацию всех сервисов
echo -e "\n===========================================\n🕒 Ожидание инициализации всех сервисов...\n==========================================="
sleep 10

# Проверка запущенных сервисов
echo -e "\n===========================================\n🔍 ФИНАЛЬНАЯ ПРОВЕРКА ВСЕХ СЕРВИСОВ\n==========================================="

# Функция для проверки статуса сервиса
check_service() {
    local service_name="$1"
    if sudo docker ps | grep -q "$service_name"; then
        echo "✅ $service_name - ЗАПУЩЕН"
        return 0
    else
        echo "❌ $service_name - НЕ ЗАПУЩЕН"
        return 1
    fi
}

# Проверяем все критические сервисы
check_service "n8n"
check_service "caddy"
check_service "postgres"
check_service "n8n_redis"
check_service "flowise"
check_service "qdrant"
check_service "crawl4ai"
check_service "watchtower"
check_service "netdata"
check_service "adminer"
check_service "wordpress"
check_service "wordpress_db"
check_service "waha"

# Проверка портов Caddy
echo -e "\n- Проверка портов Caddy:"
if sudo ss -tulpen | grep -q ':80\|:443'; then
    echo "✅ Caddy успешно слушает порты 80 и 443"
else
    echo "⚠️ Внимание: Caddy (обратный прокси) не слушает порты 80 или 443"
fi

# Вывод общего результата
echo -e "\n=========================================================\n🏁 РЕЗУЛЬТАТЫ ЗАПУСКА:"
RUNNING_COUNT=$(sudo docker ps --format "{{.Names}}" | wc -l)
echo "   ✓ Успешно запущено: $RUNNING_COUNT сервисов"
FAILED_COUNT=$(( 13 - $RUNNING_COUNT )) # 13 - общее количество сервисов
if [ $FAILED_COUNT -gt 0 ]; then
    echo "   ✗ Не запущено: $FAILED_COUNT сервисов"
else
    echo "\n✅ ВСЕ СЕРВИСЫ УСПЕШНО ЗАПУЩЕНЫ!"
fi
echo -e "\n========================================================="
echo "Сервисы успешно запущены! Скоро они станут доступны через веб-интерфейс."

exit 0
