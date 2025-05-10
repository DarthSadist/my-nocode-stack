#!/bin/bash

# Скрипт для детального анализа YAML файла

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Путь к шаблону docker-compose.yaml.template
TEMPLATE_FILE="/home/den/my-nocode-stack/docker-compose.yaml.template"
# Путь к файлу с тестовыми переменными окружения
ENV_FILE="/home/den/my-nocode-stack/test-env-temp"
# Путь к временному файлу для тестирования
TEST_OUTPUT="/tmp/docker-compose.yaml.test"

echo -e "${BLUE}====== Детальный анализ docker-compose.yaml ======${RESET}"

# Проверка наличия необходимых файлов
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл шаблона $TEMPLATE_FILE не найден!${RESET}"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл переменных окружения $ENV_FILE не найден!${RESET}"
    exit 1
fi

# Загрузка переменных окружения
set -a
source "$ENV_FILE"
set +a

# Генерация тестового файла docker-compose.yaml
envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT"

# Выборочная проверка проблемных частей файла
echo -e "\n${BLUE}Вывод строки с ошибкой и окружения (220-230):${RESET}"
sed -n '220,230p' "$TEST_OUTPUT"

echo -e "\n${BLUE}Анализ команды healthcheck для WordPress:${RESET}"
grep -n -A 5 "wordpress.*healthcheck" "$TEST_OUTPUT"

# Проверка наличия непарных кавычек в строках healthcheck
echo -e "\n${BLUE}Проверка непарных кавычек в healthcheck:${RESET}"
grep -n "test:" "$TEST_OUTPUT" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    test_line=$(sed -n "${line_num}p" "$TEST_OUTPUT")
    
    # Подсчет кавычек
    double_quotes=$(echo "$test_line" | grep -o '"' | wc -l)
    if [ $((double_quotes % 2)) -ne 0 ]; then
        echo -e "${RED}Непарные двойные кавычки в строке $line_num: $test_line${RESET}"
    fi
    
    # Анализ строки через xxd для выявления скрытых символов
    echo -e "${YELLOW}Анализ строки $line_num:${RESET}"
    sed -n "${line_num}p" "$TEST_OUTPUT" | xxd -g 1
done

echo -e "\n${BLUE}Вывод всех test: строк для анализа:${RESET}"
grep -n "test:" "$TEST_OUTPUT"
