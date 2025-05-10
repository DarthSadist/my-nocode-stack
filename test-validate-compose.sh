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
# Путь к файлу с тестовыми переменными окружения
ENV_FILE="/home/den/my-nocode-stack/test-env-temp"
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

echo -e "${BLUE}Шаг 1: Загрузка переменных окружения из $ENV_FILE${RESET}"
# Загрузка переменных окружения
set -a
source "$ENV_FILE"
set +a
echo -e "${GREEN}Переменные окружения успешно загружены${RESET}"

echo -e "${BLUE}Шаг 2: Генерация тестового файла docker-compose.yaml${RESET}"
# Генерация тестового файла docker-compose.yaml
if ! envsubst < "$TEMPLATE_FILE" > "$TEST_OUTPUT"; then
    echo -e "${RED}ОШИБКА: Не удалось сгенерировать тестовый файл!${RESET}"
    exit 1
fi
echo -e "${GREEN}Тестовый файл успешно сгенерирован: $TEST_OUTPUT${RESET}"

echo -e "${BLUE}Шаг 3: Проверка файла на наличие синтаксических ошибок YAML${RESET}"
# Для упрощения проверки используем python и PyYAML
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
    sys.exit(1)
except Exception as e:
    print(f"❌ Неизвестная ошибка:\n{e}")
    sys.exit(1)
' "$TEST_OUTPUT"

if [ $? -ne 0 ]; then
    echo -e "${RED}ОШИБКА: Сгенерированный файл содержит синтаксические ошибки YAML!${RESET}"
    
    # Попытка более детального анализа файла
    echo -e "${YELLOW}Пытаюсь определить проблемное место...${RESET}"
    
    # Вывод последних 20 строк для анализа (могут содержать ошибку)
    echo -e "${BLUE}Последние 20 строк сгенерированного файла:${RESET}"
    tail -n 20 "$TEST_OUTPUT"
    
    # Попытка найти проблемные строки с экранированием
    echo -e "${BLUE}Ищу проблемы с экранированием:${RESET}"
    grep -n "\\" "$TEST_OUTPUT" | tail -n 5
    
    # Поиск строк с переменными, которые могли не подставиться
    echo -e "${BLUE}Ищу неподставленные переменные:${RESET}"
    grep -n "\${" "$TEST_OUTPUT" || echo "Неподставленных переменных не найдено."
    
    exit 1
fi

echo -e "${GREEN}Валидация завершена успешно! Сгенерированный файл не содержит синтаксических ошибок YAML.${RESET}"

# Вывод предупреждения о том, что это только проверка синтаксиса YAML
echo -e "${YELLOW}Обратите внимание: проведена только проверка синтаксиса YAML.${RESET}"
echo -e "${YELLOW}Для полной функциональной проверки требуется запуск docker-compose.${RESET}"

exit 0
