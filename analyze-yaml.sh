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

# Разделение файла на строки и проверка каждой строки на корректность YAML
echo -e "${BLUE}Анализ файла построчно...${RESET}"
linenum=0
problematic_lines=()

while IFS= read -r line; do
    ((linenum++))
    
    # Пропуск пустых строк и комментариев
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Проверка на непарные кавычки
    if [[ $(grep -o '"' <<<"$line" | wc -l) % 2 -ne 0 ]]; then
        problematic_lines+=("$linenum: Непарные двойные кавычки: $line")
    fi
    
    if [[ $(grep -o "'" <<<"$line" | wc -l) % 2 -ne 0 ]]; then
        problematic_lines+=("$linenum: Непарные одинарные кавычки: $line")
    fi
    
    # Проверка символов табуляции
    if [[ "$line" =~ $'\t' ]]; then
        problematic_lines+=("$linenum: Содержит символы табуляции: $line")
    fi
    
    # Проверка некорректных пробелов после двоеточия
    if [[ "$line" =~ :[^ ] && ! "$line" =~ :[[:space:]]*$ && ! "$line" =~ :[[:space:]]*[\"\'[].*[\"\'\]] ]]; then
        problematic_lines+=("$linenum: Отсутствие пробела после двоеточия: $line")
    fi
    
    # Проверка символов, которые могут вызвать проблемы в YAML
    if [[ "$line" =~ [{}|>*&!%@] && ! "$line" =~ ([\"\']).+\1 ]]; then
        problematic_lines+=("$linenum: Содержит специальные символы без кавычек: $line")
    fi
    
    # Проверка экранирования в списках
    if [[ "$line" =~ \[[^\]]*\\[^\]]*\] ]]; then
        problematic_lines+=("$linenum: Непарные экранирующие символы в списке: $line")
    fi
done < "$TEST_OUTPUT"

# Вывод проблемных строк
if [ ${#problematic_lines[@]} -eq 0 ]; then
    echo -e "${GREEN}Построчный анализ не выявил очевидных проблем в синтаксисе YAML${RESET}"
else
    echo -e "${RED}Выявлены потенциальные проблемы в следующих строках:${RESET}"
    for problem in "${problematic_lines[@]}"; do
        echo -e "  $problem"
    done
fi

# Анализ значений healthcheck
echo -e "\n${BLUE}Анализ блоков healthcheck...${RESET}"
grep -n -A 5 "healthcheck:" "$TEST_OUTPUT"

# Дополнительное извлечение строки 225, которая указана в ошибке
echo -e "\n${BLUE}Вывод строки 225 и окружения:${RESET}"
sed -n '220,230p' "$TEST_OUTPUT"

# Анализ строки через xxd, чтобы увидеть все символы
echo -e "\n${BLUE}Анализ строки 225 через xxd для выявления скрытых символов:${RESET}"
sed -n '225p' "$TEST_OUTPUT" | xxd -g 1

echo -e "\n${YELLOW}Рекомендация: Проверьте строку 225 на наличие скрытых символов или синтаксических ошибок${RESET}"
echo -e "${YELLOW}Для исправления попробуйте переписать строку вручную${RESET}"
