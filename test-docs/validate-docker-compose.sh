#!/bin/bash

# Скрипт для проверки корректности генерации файла docker-compose.yaml

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Путь к шаблону docker-compose.yaml.template
TEMPLATE_FILE="/home/den/my-nocode-stack/docker-compose.yaml.template"
# Путь к файлу .env
ENV_FILE="/home/den/my-nocode-stack/.env"
# Путь к временному файлу для тестирования
TEST_OUTPUT="/tmp/docker-compose.yaml.test"

echo -e "${BLUE}====== Валидация генерации docker-compose.yaml ======${RESET}"

# Проверка наличия необходимых файлов
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл шаблона $TEMPLATE_FILE не найден!${RESET}"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл переменных окружения $ENV_FILE не найден!${RESET}"
    exit 1
fi

# Проверка наличия необходимых утилит
if ! command -v envsubst &> /dev/null; then
    echo -e "${RED}ОШИБКА: Утилита envsubst не найдена! Установите пакет gettext${RESET}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}ОШИБКА: Ни docker-compose, ни docker не найдены!${RESET}"
    exit 1
fi

echo -e "${BLUE}Шаг 1: Загрузка переменных окружения из $ENV_FILE${RESET}"
# Загрузка переменных окружения
if ! source "$ENV_FILE"; then
    echo -e "${RED}ОШИБКА: Не удалось загрузить переменные окружения из $ENV_FILE${RESET}"
    exit 1
fi
echo -e "${GREEN}Переменные окружения успешно загружены${RESET}"

echo -e "${BLUE}Шаг 2: Генерация тестового файла docker-compose.yaml${RESET}"
# Генерация тестового файла docker-compose.yaml
if ! envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT"; then
    echo -e "${RED}ОШИБКА: Не удалось сгенерировать тестовый файл!${RESET}"
    exit 1
fi
echo -e "${GREEN}Тестовый файл успешно сгенерирован: $TEST_OUTPUT${RESET}"

echo -e "${BLUE}Шаг 3: Проверка синтаксиса YAML${RESET}"
# Проверка синтаксиса YAML
if command -v docker-compose &> /dev/null; then
    if ! docker-compose -f "$TEST_OUTPUT" config > /dev/null 2>&1; then
        echo -e "${RED}ОШИБКА: В сгенерированном файле обнаружены синтаксические ошибки YAML!${RESET}"
        docker-compose -f "$TEST_OUTPUT" config
        exit 1
    fi
    echo -e "${GREEN}Синтаксис YAML проверен, ошибок не обнаружено${RESET}"
elif command -v docker &> /dev/null; then
    if ! docker compose -f "$TEST_OUTPUT" config > /dev/null 2>&1; then
        echo -e "${RED}ОШИБКА: В сгенерированном файле обнаружены синтаксические ошибки YAML!${RESET}"
        docker compose -f "$TEST_OUTPUT" config
        exit 1
    fi
    echo -e "${GREEN}Синтаксис YAML проверен, ошибок не обнаружено${RESET}"
else
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: Невозможно проверить синтаксис YAML, docker-compose не найден${RESET}"
fi

echo -e "${BLUE}Шаг 4: Проверка конфигурации сервисов${RESET}"

# Проверка конфигурации n8n
if grep -q "N8N_SKIP_WEBHOOK_PORT_PREFIX_FOR_MAIN_URL" "$TEST_OUTPUT"; then
    echo -e "${GREEN}✓ Конфигурация n8n правильная: опция пропуска порта в URL установлена${RESET}"
else
    echo -e "${RED}✗ Конфигурация n8n некорректная: не найдена опция N8N_SKIP_WEBHOOK_PORT_PREFIX_FOR_MAIN_URL${RESET}"
fi

# Проверка многострочной конфигурации WordPress
if grep -q "WORDPRESS_CONFIG_EXTRA=|" "$TEST_OUTPUT"; then
    echo -e "${GREEN}✓ Формат многострочной конфигурации WordPress корректный${RESET}"
else
    echo -e "${RED}✗ Формат многострочной конфигурации WordPress некорректный${RESET}"
fi

# Проверка наличия сети для всех сервисов
if grep -c "app-network" "$TEST_OUTPUT" > /dev/null; then
    SERVICES_COUNT=$(grep -c "container_name:" "$TEST_OUTPUT")
    NETWORK_COUNT=$(grep -c "app-network" "$TEST_OUTPUT")
    echo -e "${GREEN}✓ Все сервисы имеют определение сети: $NETWORK_COUNT сетевых подключений на $SERVICES_COUNT сервисов${RESET}"
else
    echo -e "${RED}✗ Не все сервисы имеют определение сети${RESET}"
fi

# Очистка временного файла
rm -f "$TEST_OUTPUT"

echo -e "${BLUE}====== Валидация завершена успешно ======${RESET}"
echo -e "${GREEN}Файл docker-compose.yaml.template корректен и может быть использован для генерации конфигурации${RESET}"

# Рекомендации
echo -e "${YELLOW}Рекомендации:${RESET}"
echo -e "1. При внесении изменений в шаблон регулярно запускайте этот скрипт для проверки"
echo -e "2. Перед запуском реальной установки также рекомендуется выполнить валидацию"
echo -e "3. Храните резервную копию рабочего шаблона на случай возникновения проблем"
