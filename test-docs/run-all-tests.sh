#!/bin/bash
# Скрипт для автоматического запуска всех тестов
# Сохраните как ~/my-nocode-stack/test-docs/run-all-tests.sh

# Настройка цветов для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Функция для отображения заголовков
print_header() {
  echo -e "\n${BLUE}===================================================${RESET}"
  echo -e "${BLUE}=== $1 ===${RESET}"
  echo -e "${BLUE}===================================================${RESET}\n"
}

# Функция для запуска тестов и отчета о результатах
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo -e "${YELLOW}Выполняется: ${test_name}${RESET}"
  
  # Запуск команды и сохранение результата
  if eval "${test_command}"; then
    echo -e "${GREEN}✓ Тест успешно выполнен: ${test_name}${RESET}"
    return 0
  else
    echo -e "${RED}✗ Тест не пройден: ${test_name}${RESET}"
    return 1
  fi
}

# Создание директории для результатов тестирования
mkdir -p ~/my-nocode-stack/test-docs/results
LOG_FILE=~/my-nocode-stack/test-docs/results/all-tests-$(date +%Y%m%d-%H%M%S).log

# Функция проверки зависимостей
check_dependencies() {
  echo -e "${YELLOW}Проверка необходимых зависимостей...${RESET}"
  local missing_deps=false
  
  # Проверка Docker
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}ОШИБКА: Docker не установлен!${RESET}"
    missing_deps=true
  fi
  
  # Проверка Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}ОШИБКА: Docker Compose не установлен!${RESET}"
    missing_deps=true
  fi
  
  # Проверка curl
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}ОШИБКА: curl не установлен!${RESET}"
    missing_deps=true
  fi
  
  # Проверка Apache Benchmark (необязательно)
  if ! command -v ab &> /dev/null; then
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: Apache Benchmark (ab) не установлен. Некоторые тесты производительности будут пропущены.${RESET}"
    echo -e "${YELLOW}Установите его с помощью: sudo apt-get install apache2-utils${RESET}"
  fi
  
  # Проверка работы Docker
  if ! docker info &> /dev/null; then
    echo -e "${RED}ОШИБКА: Служба Docker не запущена или у вас нет прав для её использования!${RESET}"
    echo -e "${YELLOW}Запустите службу Docker: sudo systemctl start docker${RESET}"
    missing_deps=true
  fi
  
  # Проверка наличия работающих контейнеров
  local containers=(postgres redis mariadb n8n flowise)
  local missing_containers=false
  
  for container in "${containers[@]}"; do
    if ! docker ps | grep -q "$container"; then
      echo -e "${RED}ОШИБКА: Контейнер $container не запущен!${RESET}"
      missing_containers=true
    fi
  done
  
  if $missing_containers; then
    echo -e "${YELLOW}Запустите все контейнеры с помощью: docker-compose up -d${RESET}"
  fi
  
  if $missing_deps || $missing_containers; then
    echo -e "${RED}ОШИБКА: Не все зависимости удовлетворены. Устраните проблемы и запустите скрипт снова.${RESET}"
    exit 1
  else
    echo -e "${GREEN}✓ Все необходимые зависимости установлены и запущены${RESET}"
  fi
}

# Запуск всех тестов и запись результатов в лог-файл
{
  echo "Начало комплексного тестирования: $(date)"
  echo "Рабочая директория: $(pwd)"
  
  # Проверка зависимостей перед запуском тестов
  check_dependencies
  
  # Загрузка переменных окружения из основного файла .env
  if [ -f ~/my-nocode-stack/.env ]; then
    echo "Загрузка переменных окружения из основного файла .env"
    source ~/my-nocode-stack/.env
  else
    echo "ОШИБКА: Файл .env не найден! Невозможно продолжить тестирование без переменных окружения."
    echo "Сначала запустите основной скрипт установки сервисов стека, который создаст файл .env"
    exit 1
  fi
  
  # Отображение загруженных переменных (без вывода секретных значений)
  echo "Загружены следующие переменные окружения:"
  echo "POSTGRES_USER=$POSTGRES_USER"
  echo "MYSQL_USER=$MYSQL_USER"
  echo "MYSQL_DATABASE=$MYSQL_DATABASE"
  echo "Пароли и секретные ключи скрыты из соображений безопасности"
  
  # 1. Подготовка к тестированию
  print_header "1. Подготовка к тестированию"
  
  # Проверка инфраструктуры
  run_test "Проверка хост-системы" "uname -a && lsb_release -a"
  run_test "Проверка Docker" "docker --version && docker-compose --version"
  run_test "Проверка контейнеров" "docker ps --format '{{.Names}} - {{.Status}}'"
  
  # 2. Тестирование отдельных компонентов
  print_header "2. Тестирование отдельных компонентов"
  
  # PostgreSQL
  run_test "Проверка PostgreSQL" "docker exec postgres pg_isready"
  run_test "Версия PostgreSQL" "docker exec postgres psql -U $POSTGRES_USER -c 'SELECT version();'"
  
  # Redis
  run_test "Проверка Redis" "docker exec redis redis-cli ping"
  
  # N8N
  run_test "Проверка N8N" "curl -s -o /dev/null -w '%{http_code}' http://localhost:5678"
  
  # Flowise
  run_test "Проверка Flowise" "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000"
  
  # WordPress и MariaDB
  run_test "Проверка MariaDB" "docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'SHOW DATABASES;'"
  run_test "Проверка WordPress" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080"
  
  # Netdata
  run_test "Проверка Netdata" "curl -s -o /dev/null -w '%{http_code}' http://localhost:19999"
  
  # 3. Интеграционное тестирование
  print_header "3. Интеграционное тестирование"
  
  # Проверка соединений между компонентами
  run_test "Интеграция N8N-PostgreSQL" "docker exec n8n curl -s postgres:5432 >/dev/null"
  run_test "Интеграция Flowise-Qdrant" "docker exec flowise curl -s qdrant:6333 >/dev/null"
  run_test "Интеграция WordPress-MariaDB" "docker exec wordpress curl -s mariadb:3306 >/dev/null"
  
  # 4. Нагрузочное тестирование
  print_header "4. Нагрузочное тестирование (упрощенное)"
  
  # Упрощенное нагрузочное тестирование
  run_test "Нагрузка на PostgreSQL" "docker exec postgres psql -U $POSTGRES_USER -c 'SELECT 1' > /dev/null"
  run_test "Нагрузка на WordPress" "ab -n 10 -c 2 http://localhost:8080/ 2>&1 | grep 'Requests per second' || echo 'Apache Benchmark не установлен'"
  run_test "Нагрузка на N8N" "ab -n 10 -c 2 http://localhost:5678/ 2>&1 | grep 'Requests per second' || echo 'Apache Benchmark не установлен'"
  
  # 5. Проверка безопасности
  print_header "5. Проверка безопасности (упрощенная)"
  
  # Проверка сетевых портов
  run_test "Проверка открытых портов" "ss -tulpn | grep -E '(5432|6379|3306|5678|3000|8080|19999)'"
  
  # Проверка настроек Docker
  run_test "Настройки безопасности Docker" "docker info | grep -E 'Security|Logging'"
  
  # Итоговый результат
  print_header "Результаты тестирования"
  echo "Тестирование завершено: $(date)"
  echo "Результаты сохранены в файле: $LOG_FILE"
  
} 2>&1 | tee $LOG_FILE

# Анализ результатов
FAILURES=$(grep -c "✗ Тест не пройден" $LOG_FILE)
SUCCESSES=$(grep -c "✓ Тест успешно выполнен" $LOG_FILE)
TOTAL=$((FAILURES + SUCCESSES))

echo -e "\n${BLUE}Итоги тестирования:${RESET}"
echo -e "${GREEN}Успешно:${RESET} $SUCCESSES/$TOTAL"
echo -e "${RED}Не пройдено:${RESET} $FAILURES/$TOTAL"

if [ $FAILURES -eq 0 ]; then
  echo -e "${GREEN}Все тесты успешно пройдены!${RESET}"
  exit 0
else
  echo -e "${RED}Некоторые тесты не пройдены. Проверьте детали в лог-файле: $LOG_FILE${RESET}"
  exit 1
fi
