#!/bin/bash

# Скрипт для отладки процесса создания docker-compose.yaml

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
# Путь к файлу с отладочной информацией
DEBUG_FILE="/tmp/compose-debug.log"

echo -e "${BLUE}====== Отладка процесса создания docker-compose.yaml ======${RESET}" | tee "$DEBUG_FILE"

# Проверка наличия необходимых файлов
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл шаблона $TEMPLATE_FILE не найден!${RESET}" | tee -a "$DEBUG_FILE"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ОШИБКА: Файл переменных окружения $ENV_FILE не найден!${RESET}" | tee -a "$DEBUG_FILE"
    exit 1
fi

echo -e "${BLUE}Шаг 1: Проверка синтаксиса шаблона${RESET}" | tee -a "$DEBUG_FILE"
# Проверяем каждую строку шаблона на потенциальные проблемы
problematic_lines=()
line_number=0

while IFS= read -r line; do
    ((line_number++))
    
    # Анализ строк с test: на непарные кавычки
    if [[ "$line" =~ test: ]]; then
        double_quotes=$(echo "$line" | grep -o '"' | wc -l)
        if [ $((double_quotes % 2)) -ne 0 ]; then
            problematic_lines+=("$line_number: Непарные двойные кавычки: $line")
            echo -e "${RED}Строка $line_number: Непарные двойные кавычки${RESET}" | tee -a "$DEBUG_FILE"
            echo "$line" | tee -a "$DEBUG_FILE"
        fi
        
        # Анализ экранирования внутри строки
        if [[ "$line" =~ \".*\\[^\"]*\" ]]; then
            echo -e "${YELLOW}Строка $line_number: Возможная проблема с экранированием${RESET}" | tee -a "$DEBUG_FILE"
            echo "$line" | tee -a "$DEBUG_FILE"
        fi
    fi
    
    # Анализ строк с environment: на многострочные значения
    if [[ "$line" =~ EXTRA= ]] && [[ ! "$line" =~ EXTRA=[\|\>] ]]; then
        echo -e "${YELLOW}Строка $line_number: Многострочное значение без символа | или >${RESET}" | tee -a "$DEBUG_FILE"
        echo "$line" | tee -a "$DEBUG_FILE"
    fi
    
    # Анализ неправильных имен переменных
    if [[ "$line" =~ \$\{MYSQL_ ]]; then
        echo -e "${RED}Строка $line_number: Использование переменной MYSQL_ (должно быть WP_DB_)${RESET}" | tee -a "$DEBUG_FILE"
        echo "$line" | tee -a "$DEBUG_FILE"
    fi
done < "$TEMPLATE_FILE"

# Загрузка переменных окружения
echo -e "${BLUE}Шаг 2: Загрузка переменных окружения из $ENV_FILE${RESET}" | tee -a "$DEBUG_FILE"
set -a
source "$ENV_FILE"
set +a
echo -e "${GREEN}Переменные окружения успешно загружены${RESET}" | tee -a "$DEBUG_FILE"

# Вывод значений критичных переменных для отладки
echo -e "${BLUE}Значения критичных переменных:${RESET}" | tee -a "$DEBUG_FILE"
echo "DOMAIN_NAME=$DOMAIN_NAME" | tee -a "$DEBUG_FILE"
echo "WP_DB_USER=$WP_DB_USER" | tee -a "$DEBUG_FILE"
echo "WP_DB_PASSWORD=$WP_DB_PASSWORD" | tee -a "$DEBUG_FILE"
echo "POSTGRES_USER=$POSTGRES_USER" | tee -a "$DEBUG_FILE"
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" | tee -a "$DEBUG_FILE"

# Генерация тестового файла docker-compose.yaml
echo -e "${BLUE}Шаг 3: Генерация тестового файла docker-compose.yaml${RESET}" | tee -a "$DEBUG_FILE"
if ! envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT" 2>> "$DEBUG_FILE"; then
    echo -e "${RED}ОШИБКА: Не удалось сгенерировать тестовый файл!${RESET}" | tee -a "$DEBUG_FILE"
    exit 1
fi
echo -e "${GREEN}Тестовый файл успешно сгенерирован: $TEST_OUTPUT${RESET}" | tee -a "$DEBUG_FILE"

# Проверка синтаксиса YAML с выводом ошибок
echo -e "${BLUE}Шаг 4: Проверка синтаксиса YAML${RESET}" | tee -a "$DEBUG_FILE"
python3 -c '
import sys
try:
    import yaml
    with open(sys.argv[1], "r") as f:
        yaml.safe_load(f)
    print("✅ Синтаксис YAML корректен")
except ImportError:
    print("⚠️ Python библиотека PyYAML не установлена. Установите ее с помощью: pip install pyyaml")
    sys.exit(2)
except yaml.YAMLError as e:
    print(f"❌ Обнаружена ошибка YAML синтаксиса:\n{e}")
    # Определение строки с ошибкой
    error_line = None
    if hasattr(e, "problem_mark"):
        error_line = e.problem_mark.line + 1
        print(f"Ошибка найдена в строке {error_line}")
        
    # Вывод области с ошибкой
    if error_line:
        start_line = max(1, error_line - 5)
        end_line = error_line + 5
        with open(sys.argv[1], "r") as f:
            lines = f.readlines()
            for i in range(start_line-1, min(end_line, len(lines))):
                if i+1 == error_line:
                    print(f">>> {i+1}: {lines[i].rstrip()}")
                else:
                    print(f"    {i+1}: {lines[i].rstrip()}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Неизвестная ошибка:\n{e}")
    sys.exit(1)
' "$TEST_OUTPUT" 2>&1 | tee -a "$DEBUG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}ОШИБКА: Сгенерированный файл содержит синтаксические ошибки YAML!${RESET}" | tee -a "$DEBUG_FILE"
    
    # Поиск возможных проблем в сгенерированном файле
    echo -e "${YELLOW}Анализ проблемных мест...${RESET}" | tee -a "$DEBUG_FILE"
    
    # Проверка наличия непарных кавычек в строках test:
    echo -e "${BLUE}Проверка блоков test: на непарные кавычки:${RESET}" | tee -a "$DEBUG_FILE"
    grep -n "test:" "$TEST_OUTPUT" | while read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        content=$(sed -n "${line_num}p" "$TEST_OUTPUT")
        echo "Строка $line_num: $content" | tee -a "$DEBUG_FILE"
        
        # Вывод hex-дампа для анализа скрытых символов
        echo "HEX:" | tee -a "$DEBUG_FILE"
        sed -n "${line_num}p" "$TEST_OUTPUT" | xxd -g 1 | tee -a "$DEBUG_FILE"
    done
    
    # Создание структурированного дампа для анализа
    echo -e "${BLUE}Создание структурированного дампа для анализа:${RESET}" | tee -a "$DEBUG_FILE"
    python3 -c '
import sys, json, yaml
try:
    with open(sys.argv[1], "r") as f:
        # Попытка загрузить первые верные части YAML
        try:
            doc = yaml.safe_load(f)
            print("YAML file structure (partial):")
            print(json.dumps(doc, indent=2))
        except Exception as e:
            print(f"Error parsing YAML: {e}")
            
        # Попытка линейного анализа
        f.seek(0)
        lines = f.readlines()
        # Разбиваем файл на секции верхнего уровня и анализируем каждую
        current_section = ""
        section_data = ""
        section_start_line = 0
        sections = {}
        
        for i, line in enumerate(lines):
            if line.strip() and not line.strip().startswith("#") and not line[0].isspace():
                # Новая секция верхнего уровня
                if current_section:
                    # Сохраняем предыдущую секцию
                    sections[current_section] = {
                        "start_line": section_start_line,
                        "end_line": i,
                        "content": section_data
                    }
                current_section = line.strip(":")
                section_data = line
                section_start_line = i + 1
            else:
                section_data += line
        
        # Добавляем последнюю секцию
        if current_section:
            sections[current_section] = {
                "start_line": section_start_line,
                "end_line": len(lines),
                "content": section_data
            }
        
        # Анализируем каждую секцию отдельно
        for section, data in sections.items():
            print(f"\nAnalyzing section: {section} (lines {data[\'start_line\']} - {data[\'end_line\']})")
            try:
                yaml.safe_load(data["content"])
                print(f"Section {section} is valid YAML")
            except Exception as e:
                print(f"Section {section} has YAML errors: {e}")
except Exception as e:
    print(f"Error in analysis: {e}")
' "$TEST_OUTPUT" | tee -a "$DEBUG_FILE"
    
    exit 1
fi

echo -e "${GREEN}✅ YAML-файл корректен! Установка должна пройти успешно.${RESET}" | tee -a "$DEBUG_FILE"

# Создаем исправленный шаблон для docker-compose
echo -e "${BLUE}Шаг 5: Проверка работы docker-compose config${RESET}" | tee -a "$DEBUG_FILE"
if command -v docker-compose &> /dev/null; then
    docker-compose -f "$TEST_OUTPUT" config > /dev/null 2>> "$DEBUG_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ docker-compose config успешно выполнен${RESET}" | tee -a "$DEBUG_FILE"
    else
        echo -e "${RED}❌ docker-compose config завершился с ошибкой${RESET}" | tee -a "$DEBUG_FILE"
        docker-compose -f "$TEST_OUTPUT" config 2>&1 | tee -a "$DEBUG_FILE"
    fi
elif command -v docker &> /dev/null; then
    docker compose -f "$TEST_OUTPUT" config > /dev/null 2>> "$DEBUG_FILE"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ docker compose config успешно выполнен${RESET}" | tee -a "$DEBUG_FILE"
    else
        echo -e "${RED}❌ docker compose config завершился с ошибкой${RESET}" | tee -a "$DEBUG_FILE"
        docker compose -f "$TEST_OUTPUT" config 2>&1 | tee -a "$DEBUG_FILE"
    fi
else
    echo -e "${YELLOW}⚠️ docker-compose не найден, пропускаем проверку${RESET}" | tee -a "$DEBUG_FILE"
fi

echo -e "${BLUE}====== Отладка завершена ======${RESET}" | tee -a "$DEBUG_FILE"
echo -e "${GREEN}Результаты отладки сохранены в файл: $DEBUG_FILE${RESET}"

# Вывод тестового файла для анализа
echo -e "${YELLOW}Для детального анализа вы можете просмотреть тестовый файл:${RESET}"
echo -e "  cat $TEST_OUTPUT"
echo -e "${YELLOW}А также файл с отладочной информацией:${RESET}"
echo -e "  cat $DEBUG_FILE"
