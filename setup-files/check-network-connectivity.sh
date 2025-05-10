#!/bin/bash

# Скрипт для проверки сетевого взаимодействия между сервисами Docker
# Автор: Cascade 2025-05-07

# Цветовые коды для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Функция для отображения заголовков
show_header() {
    echo -e "\n${YELLOW}============================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}============================================${NC}\n"
}

# Функция проверки сетевого взаимодействия
check_network_connectivity() {
    local service="$1"
    local target="$2"
    echo -n "🔍 Проверка сетевого доступа от $service до $target... "
    
    if sudo docker exec "$service" ping -c 1 -W 2 "$target" &> /dev/null; then
        echo -e "${GREEN}✅ ДОСТУПЕН${NC}"
        return 0
    else
        echo -e "${RED}❌ НЕДОСТУПЕН${NC}" >&2
        return 1
    fi
}

# Проверка наличия запущенного Docker
if ! sudo docker info &>/dev/null; then
    echo -e "${RED}❌ Docker не запущен или недоступен${NC}" >&2
    exit 1
fi

# Проверка наличия сети app-network
show_header "ПРОВЕРКА СЕТИ DOCKER"
echo -n "🔍 Проверка наличия сети app-network... "
if sudo docker network ls | grep -q "app-network"; then
    echo -e "${GREEN}✅ СЕТЬ СУЩЕСТВУЕТ${NC}"
else
    echo -e "${RED}❌ СЕТЬ НЕ СУЩЕСТВУЕТ${NC}" >&2
    echo -e "${YELLOW}🔄 Создаю сеть app-network...${NC}"
    sudo docker network create app-network
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Сеть app-network успешно создана${NC}"
    else
        echo -e "${RED}❌ Не удалось создать сеть app-network${NC}" >&2
        exit 1
    fi
fi

# Проверка сервисов в сети
show_header "ПРОВЕРКА СЕРВИСОВ В СЕТИ APP-NETWORK"
echo "📋 Список контейнеров в сети app-network:"
sudo docker network inspect app-network --format '{{range .Containers}}{{.Name}} {{end}}' | tr ' ' '\n' | grep -v '^$'

# Получение списка запущенных контейнеров
RUNNING_CONTAINERS=$(sudo docker ps --format "{{.Names}}")

# Выбор контейнера для тестирования
TEST_CONTAINER=""
for container in caddy n8n flowise postgres netdata; do
    if echo "$RUNNING_CONTAINERS" | grep -q "$container"; then
        TEST_CONTAINER="$container"
        break
    fi
done

if [ -z "$TEST_CONTAINER" ]; then
    echo -e "${RED}❌ Не найден подходящий контейнер для тестирования сети${NC}" >&2
    exit 1
fi

echo -e "\n🔍 Используем контейнер ${GREEN}$TEST_CONTAINER${NC} для тестирования сети"

# Список сервисов для проверки
SERVICES_TO_CHECK=("postgres" "n8n" "n8n_redis" "qdrant" "flowise" "caddy" "netdata" "wordpress" "wordpress_db")

# Проверка сетевого взаимодействия между сервисами
show_header "ПРОВЕРКА СЕТЕВОГО ВЗАИМОДЕЙСТВИЯ МЕЖДУ СЕРВИСАМИ"
NETWORK_ERRORS=0

for service in "${SERVICES_TO_CHECK[@]}"; do
    if echo "$RUNNING_CONTAINERS" | grep -q "$service"; then
        check_network_connectivity "$TEST_CONTAINER" "$service" || ((NETWORK_ERRORS++))
    else
        echo -e "ℹ️ Сервис $service не запущен, пропускаем проверку"
    fi
done

# Проверка DNS конфигурации
show_header "ПРОВЕРКА DNS КОНФИГУРАЦИИ"
echo -e "📋 Содержимое /etc/resolv.conf в контейнере $TEST_CONTAINER:"
sudo docker exec "$TEST_CONTAINER" cat /etc/resolv.conf

# Проверка /etc/hosts в контейнере
echo -e "\n📋 Содержимое /etc/hosts в контейнере $TEST_CONTAINER:"
sudo docker exec "$TEST_CONTAINER" cat /etc/hosts

# Информация о сети Docker
show_header "ДЕТАЛИ СЕТИ APP-NETWORK"
echo "📋 Информация о сети app-network:"
sudo docker network inspect app-network | grep -E "Name|Driver|Subnet|Gateway|Containers"

# Итоги проверки
show_header "РЕЗУЛЬТАТЫ ПРОВЕРКИ СЕТЕВОГО ВЗАИМОДЕЙСТВИЯ"
if [ $NETWORK_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Сетевое взаимодействие между сервисами работает корректно!${NC}"
else
    echo -e "${RED}❌ Обнаружены проблемы с сетевым взаимодействием ($NETWORK_ERRORS ошибок)${NC}" >&2
    echo -e "${YELLOW}💡 Возможные решения:${NC}" >&2
    echo "  - Перезагрузить сеть Docker: sudo docker network rm app-network && sudo docker network create app-network" >&2
    echo "  - Перезапустить службу Docker: sudo systemctl restart docker" >&2
    echo "  - Перезапустить все сервисы: sudo docker compose -f /opt/docker-compose.yaml --env-file /opt/.env down && sudo docker compose -f /opt/docker-compose.yaml --env-file /opt/.env up -d" >&2
fi

exit $NETWORK_ERRORS
