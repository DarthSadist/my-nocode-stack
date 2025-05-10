#!/bin/bash

# Скрипт для автоматизированного тестирования вебхуков n8n

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Загрузка переменных окружения
ENV_FILE="/home/den/my-nocode-stack/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}ОШИБКА: Файл .env не найден!${RESET}"
    exit 1
fi

# Проверка наличия необходимых переменных
if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}ОШИБКА: Переменная DOMAIN_NAME не определена в файле .env${RESET}"
    exit 1
fi

# Проверка доступности сервисов
echo -e "${BLUE}====== Тестирование вебхуков n8n ======${RESET}"

# Проверка, запущен ли контейнер n8n
if ! docker ps | grep -q "n8n"; then
    echo -e "${RED}ОШИБКА: Контейнер n8n не запущен!${RESET}"
    exit 1
fi

echo -e "${BLUE}Шаг 1: Проверка конфигурации n8n${RESET}"
# Проверка конфигурации n8n
if ! docker exec n8n env | grep -q "N8N_SKIP_WEBHOOK_PORT_PREFIX_FOR_MAIN_URL=true"; then
    echo -e "${RED}ОШИБКА: Переменная N8N_SKIP_WEBHOOK_PORT_PREFIX_FOR_MAIN_URL не установлена или имеет неверное значение${RESET}"
    echo -e "${YELLOW}Текущие настройки:${RESET}"
    docker exec n8n env | grep -E "N8N_(HOST|WEBHOOK|PORT|SKIP)"
    exit 1
fi
echo -e "${GREEN}✓ Конфигурация n8n корректна${RESET}"

echo -e "${BLUE}Шаг 2: Проверка доступности веб-интерфейса n8n${RESET}"
# Проверка доступности n8n через Caddy
n8n_url="https://n8n.${DOMAIN_NAME}"
if ! curl -I -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$n8n_url" | grep -q -e "200" -e "302"; then
    echo -e "${RED}ОШИБКА: Веб-интерфейс n8n недоступен по адресу $n8n_url${RESET}"
    exit 1
fi
echo -e "${GREEN}✓ Веб-интерфейс n8n доступен по адресу $n8n_url${RESET}"

echo -e "${BLUE}Шаг 3: Проверка формата URL вебхуков${RESET}"
# Получение информации о n8n API и проверка формата URL
if ! curl -s "$n8n_url/api/v1/executions" -u "${N8N_DEFAULT_USER_EMAIL}:${N8N_DEFAULT_USER_PASSWORD}" | grep -q "data"; then
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: Не удалось проверить API n8n. Возможно, требуется аутентификация.${RESET}"
else
    echo -e "${GREEN}✓ API n8n доступен${RESET}"
fi

echo -e "${BLUE}Шаг 4: Создание тестового вебхука${RESET}"
# Создание тестового рабочего процесса с вебхуком
echo -e "${YELLOW}Для полного тестирования необходимо создать тестовый вебхук через веб-интерфейс n8n:${RESET}"
echo -e "1. Перейдите по адресу: $n8n_url"
echo -e "2. Создайте новый рабочий процесс"
echo -e "3. Добавьте узел типа 'Webhook'"
echo -e "4. Настройте метод HTTP (например, POST)"
echo -e "5. Активируйте рабочий процесс"
echo -e "6. Скопируйте URL вебхука и проверьте, что он НЕ содержит номер порта"

# Функция для валидации URL вебхука
validate_webhook_url() {
    local webhook_url=$1
    if [[ "$webhook_url" =~ :[0-9]+/ ]]; then
        echo -e "${RED}ОШИБКА: URL вебхука '$webhook_url' содержит порт!${RESET}"
        return 1
    fi
    
    if [[ ! "$webhook_url" =~ ^https://n8n\.$DOMAIN_NAME/webhook/ ]]; then
        echo -e "${RED}ОШИБКА: URL вебхука '$webhook_url' имеет неправильный формат!${RESET}"
        echo -e "${YELLOW}Ожидаемый формат: https://n8n.$DOMAIN_NAME/webhook/...${RESET}"
        return 1
    fi
    
    return 0
}

# Интерактивная проверка URL вебхука
echo -e "${BLUE}Шаг 5: Проверка URL вебхука${RESET}"
read -p "Вставьте скопированный URL вебхука (или нажмите Enter для пропуска): " webhook_url

if [ -n "$webhook_url" ]; then
    if validate_webhook_url "$webhook_url"; then
        echo -e "${GREEN}✓ URL вебхука имеет правильный формат${RESET}"
        
        # Тестирование вебхука
        echo -e "${BLUE}Шаг 6: Отправка тестового запроса к вебхуку${RESET}"
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"test":"data"}' "$webhook_url")
        
        if [ "$response" = "200" ]; then
            echo -e "${GREEN}✓ Тестовый запрос успешно отправлен, получен ответ: $response${RESET}"
        else
            echo -e "${RED}ОШИБКА: Тестовый запрос не был успешно обработан, код ответа: $response${RESET}"
        fi
    fi
else
    echo -e "${YELLOW}Проверка URL вебхука пропущена${RESET}"
fi

echo -e "${BLUE}====== Проверка журналов n8n ======${RESET}"
# Проверка журналов n8n на наличие ошибок, связанных с вебхуками
webhook_errors=$(docker logs --tail 50 n8n 2>&1 | grep -i -e "webhook.*error" -e "webhook.*failed")
if [ -n "$webhook_errors" ]; then
    echo -e "${RED}ПРЕДУПРЕЖДЕНИЕ: В журналах n8n обнаружены ошибки, связанные с вебхуками:${RESET}"
    echo "$webhook_errors"
else
    echo -e "${GREEN}✓ В журналах n8n не обнаружено ошибок, связанных с вебхуками${RESET}"
fi

echo -e "${BLUE}====== Тестирование вебхуков n8n завершено ======${RESET}"
echo -e "${GREEN}Все проверки выполнены${RESET}"

# Рекомендации
echo -e "${YELLOW}Рекомендации:${RESET}"
echo -e "1. Регулярно выполняйте этот скрипт после обновления конфигурации"
echo -e "2. При изменении настроек Caddy или n8n всегда проверяйте работу вебхуков"
echo -e "3. Для продакшн-среды настройте мониторинг доступности вебхуков"
