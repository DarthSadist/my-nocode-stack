#!/bin/bash
# Скрипт для автоматического обновления документации по тестированию
# Сохраните как ~/my-nocode-stack/test-docs/update-documentation.sh

# Настройка цветов для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Директории документации и результатов
DOCS_DIR=~/my-nocode-stack/test-docs
RESULTS_DIR=$DOCS_DIR/results
mkdir -p $RESULTS_DIR

# Функция для отображения заголовков
print_header() {
  echo -e "\n${BLUE}===================================================${RESET}"
  echo -e "${BLUE}=== $1 ===${RESET}"
  echo -e "${BLUE}===================================================${RESET}\n"
}

# Функция для обновления секций в файлах документации
update_section() {
  local file="$1"
  local section_title="$2"
  local section_content="$3"
  
  if grep -q "### $section_title" "$file"; then
    # Секция существует, обновляем ее содержимое
    sed -i "/### $section_title/,/###/c\### $section_title\n\n$section_content\n\n###" "$file"
    echo -e "${GREEN}✓ Обновлена секция '$section_title' в файле '$file'${RESET}"
  else
    # Секция не существует, добавляем ее в конец файла
    echo -e "\n### $section_title\n\n$section_content" >> "$file"
    echo -e "${GREEN}✓ Добавлена новая секция '$section_title' в файл '$file'${RESET}"
  fi
}

# Проверка наличия файла .env
if [ ! -f ~/my-nocode-stack/.env ]; then
  echo -e "${RED}ОШИБКА: Файл .env не найден! Невозможно обновить документацию.${RESET}"
  exit 1
fi

print_header "Обновление документации по тестированию"

# Загрузка переменных окружения
source ~/my-nocode-stack/.env

echo -e "${YELLOW}Загружены переменные окружения из .env${RESET}"

# Обновление информации о компонентах в файле testing-index.md
echo -e "${YELLOW}Проверка состояния компонентов системы...${RESET}"

SERVICES=$(docker-compose ps --services 2>/dev/null)
if [ $? -ne 0 ]; then
  echo -e "${RED}ОШИБКА: Не удалось получить список сервисов. Проверьте docker-compose.yml${RESET}"
else
  # Генерация списка сервисов
  SERVICE_LIST=""
  for service in $SERVICES; do
    status=$(docker ps --filter "name=$service" --format "{{.Status}}" | grep -o "Up\|Exited\|Created")
    if [ "$status" == "Up" ]; then
      SERVICE_LIST="$SERVICE_LIST\n- ${GREEN}✓ $service${RESET} - запущен и работает"
    elif [ "$status" == "Exited" ]; then
      SERVICE_LIST="$SERVICE_LIST\n- ${RED}✗ $service${RESET} - остановлен"
    elif [ "$status" == "Created" ]; then
      SERVICE_LIST="$SERVICE_LIST\n- ${YELLOW}? $service${RESET} - создан, но не запущен"
    else
      SERVICE_LIST="$SERVICE_LIST\n- ${YELLOW}? $service${RESET} - неизвестное состояние"
    fi
  done
  
  echo -e "Состояние сервисов:\n$SERVICE_LIST"
  
  # Создание временного файла с актуальным списком сервисов
  TEMP_SERVICE_FILE=$(mktemp)
  echo -e "## Текущее состояние компонентов\n\nПоследнее обновление: $(date)\n" > $TEMP_SERVICE_FILE
  echo -e "Список компонентов стека:\n" >> $TEMP_SERVICE_FILE
  for service in $SERVICES; do
    status=$(docker ps --filter "name=$service" --format "{{.Status}}" | grep -o "Up\|Exited\|Created")
    if [ "$status" == "Up" ]; then
      echo "- ✅ $service - работает" >> $TEMP_SERVICE_FILE
    elif [ "$status" == "Exited" ]; then
      echo "- ❌ $service - остановлен" >> $TEMP_SERVICE_FILE
    else
      echo "- ⚠️ $service - состояние неизвестно" >> $TEMP_SERVICE_FILE
    fi
  done
  
  # Обновление информации в файле testing-index.md
  if [ -f $DOCS_DIR/testing-index.md ]; then
    # Проверка наличия раздела о состоянии сервисов
    if grep -q "## Текущее состояние компонентов" $DOCS_DIR/testing-index.md; then
      # Раздел существует, обновляем его
      sed -i '/## Текущее состояние компонентов/,/##/{ /##/{p; r '"$TEMP_SERVICE_FILE"' d}; /##/!d; }' $DOCS_DIR/testing-index.md
      echo -e "${GREEN}✓ Обновлена информация о состоянии компонентов в testing-index.md${RESET}"
    else
      # Раздел не существует, добавляем его перед "## Проверка и исправление ошибок"
      if grep -q "## Проверка и исправление ошибок" $DOCS_DIR/testing-index.md; then
        sed -i '/## Проверка и исправление ошибок/e cat '"$TEMP_SERVICE_FILE"'' $DOCS_DIR/testing-index.md
        echo -e "${GREEN}✓ Добавлена информация о состоянии компонентов в testing-index.md${RESET}"
      else
        # Добавляем в конец файла
        cat $TEMP_SERVICE_FILE >> $DOCS_DIR/testing-index.md
        echo -e "${GREEN}✓ Добавлена информация о состоянии компонентов в конец testing-index.md${RESET}"
      fi
    fi
    
    # Добавление информации о последнем обновлении
    UPDATE_DATE="Последнее обновление документации: $(date)"
    if grep -q "Последнее обновление документации:" $DOCS_DIR/testing-index.md; then
      # Строка существует, обновляем ее
      sed -i 's/Последнее обновление документации:.*/'"$UPDATE_DATE"'/' $DOCS_DIR/testing-index.md
    else
      # Строка не существует, добавляем ее после заголовка
      sed -i '1s/^/# Индекс документации по тестированию My NoCode Stack\n\n'"$UPDATE_DATE"'\n\n/' $DOCS_DIR/testing-index.md
    fi
  else
    echo -e "${RED}ОШИБКА: Файл testing-index.md не найден!${RESET}"
  fi
  
  rm $TEMP_SERVICE_FILE
fi

# Обновление списка проверяемых портов в файлах по безопасности
echo -e "${YELLOW}Обновление списка проверяемых портов...${RESET}"

# Получаем список используемых портов из docker-compose
EXPOSED_PORTS=$(docker ps --format "{{.Ports}}" | grep -o "[0-9]*->" | tr -d "->")
if [ -n "$EXPOSED_PORTS" ]; then
  # Создаем строку портов для скриптов
  PORTS_STRING=$(echo "$EXPOSED_PORTS" | tr '\n' '|' | sed 's/|$//')
  
  # Обновляем порты в файлах безопасности
  for security_file in $DOCS_DIR/security-testing-improved-part*.md; do
    if [ -f "$security_file" ]; then
      # Заменяем строки со списком портов в файлах
      sed -i 's/grep -E "(.*)".*# Проверка открытых портов/grep -E "('"$PORTS_STRING"')"  # Проверка открытых портов/' "$security_file"
      echo -e "${GREEN}✓ Обновлены порты для проверки в файле '$security_file'${RESET}"
    fi
  done
  
  # Обновление в скрипте автоматического тестирования
  if [ -f $DOCS_DIR/run-all-tests.sh ]; then
    sed -i 's/grep -E "(.*)".*# Проверка открытых портов/grep -E "('"$PORTS_STRING"')"  # Проверка открытых портов/' "$DOCS_DIR/run-all-tests.sh"
    echo -e "${GREEN}✓ Обновлены порты для проверки в скрипте run-all-tests.sh${RESET}"
  fi
fi

# Обновление информации о версиях ПО
echo -e "${YELLOW}Обновление информации о версиях ПО...${RESET}"

VERSION_INFO="## Версии компонентов\n\nПоследнее обновление: $(date)\n\n"

# Получаем версии компонентов
POSTGRES_VERSION=$(docker exec postgres psql -V 2>/dev/null | grep -o "PostgreSQL [0-9.]*" || echo "PostgreSQL (не запущен)")
REDIS_VERSION=$(docker exec redis redis-server --version 2>/dev/null | grep -o "Redis server v=.*" || echo "Redis (не запущен)")
MARIADB_VERSION=$(docker exec mariadb mysql --version 2>/dev/null | grep -o "Ver [0-9.]*" || echo "MariaDB (не запущен)")
N8N_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "n8n (не запущен)")
NODEJS_VERSION=$(docker exec n8n node --version 2>/dev/null || echo "Node.js (не запущен)")

VERSION_INFO+="- $POSTGRES_VERSION\n"
VERSION_INFO+="- $REDIS_VERSION\n"
VERSION_INFO+="- $MARIADB_VERSION\n"
VERSION_INFO+="- n8n: $N8N_VERSION\n"
VERSION_INFO+="- Node.js: $NODEJS_VERSION\n"

# Записываем информацию о версиях в файл
TEMP_VERSION_FILE=$(mktemp)
echo -e "$VERSION_INFO" > $TEMP_VERSION_FILE

# Обновляем информацию в файле testing-fixes.md
if [ -f $DOCS_DIR/testing-fixes.md ]; then
  if grep -q "## Версии компонентов" $DOCS_DIR/testing-fixes.md; then
    # Раздел существует, обновляем его
    sed -i '/## Версии компонентов/,/##/{ /##/{p; r '"$TEMP_VERSION_FILE"' d}; /##/!d; }' $DOCS_DIR/testing-fixes.md
    echo -e "${GREEN}✓ Обновлена информация о версиях компонентов в testing-fixes.md${RESET}"
  else
    # Раздел не существует, добавляем его перед разделом рекомендаций
    if grep -q "## Рекомендации" $DOCS_DIR/testing-fixes.md; then
      sed -i '/## Рекомендации/e cat '"$TEMP_VERSION_FILE"'' $DOCS_DIR/testing-fixes.md
      echo -e "${GREEN}✓ Добавлена информация о версиях компонентов в testing-fixes.md${RESET}"
    else
      # Добавляем в конец файла
      cat $TEMP_VERSION_FILE >> $DOCS_DIR/testing-fixes.md
      echo -e "${GREEN}✓ Добавлена информация о версиях компонентов в конец testing-fixes.md${RESET}"
    fi
  fi
else
  echo -e "${RED}ОШИБКА: Файл testing-fixes.md не найден!${RESET}"
fi

rm $TEMP_VERSION_FILE

# Проверка соответствия URL-путей в документации
echo -e "${YELLOW}Проверка соответствия URL-путей в документации...${RESET}"

# Получение доменных имен из .env файла
if grep -q "DOMAIN=" ~/my-nocode-stack/.env; then
  BASE_DOMAIN=$(grep "DOMAIN=" ~/my-nocode-stack/.env | cut -d= -f2)
  echo -e "Обнаружен базовый домен: $BASE_DOMAIN"
  
  # Обновляем доменные имена в файлах документации
  for doc_file in $DOCS_DIR/*.md; do
    # Заменяем example.com на актуальный домен
    sed -i "s/example\.com/$BASE_DOMAIN/g" "$doc_file"
    echo -e "${GREEN}✓ Обновлены доменные имена в файле '$doc_file'${RESET}"
  done
else
  echo -e "${YELLOW}Базовый домен не найден в .env файле. Используется example.com${RESET}"
fi

# Создание итогового отчета
print_header "Итоги обновления документации"
echo -e "${GREEN}Документация успешно обновлена.${RESET}"
echo -e "Обновленные файлы:"
echo -e "- testing-index.md - добавлена информация о состоянии компонентов"
echo -e "- testing-fixes.md - обновлены версии компонентов"
echo -e "- Файлы по безопасности - обновлены порты для проверки"
echo -e "- Все файлы - обновлены доменные имена"

echo -e "\nДата обновления: $(date)"
echo -e "Чтобы запустить тесты, выполните: bash $DOCS_DIR/run-all-tests.sh"

# Делаем скрипт исполняемым
chmod +x $DOCS_DIR/update-documentation.sh
chmod +x $DOCS_DIR/run-all-tests.sh
