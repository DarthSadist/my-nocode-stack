#!/bin/bash

# =================================================================
# Скрипт самодиагностики и восстановления системы
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
LOG_FILE="/var/log/system-diagnostics.log"
DOCKER_COMPOSE_FILE="/opt/docker-compose.yaml"
REPORT_FILE="/tmp/diagnostics-report.txt"
IS_INTERACTIVE=true
AUTO_RECOVERY=false
SEND_NOTIFICATIONS=true
NOTIFICATION_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Функция для логирования сообщений
log_message() {
  local level=$1
  local message=$2
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Вывод в консоль если в интерактивном режиме
  if [ "${IS_INTERACTIVE}" = true ]; then
    case $level in
      "INFO")
        echo -e "${GREEN}[INFO]${NC} ${timestamp}: ${message}"
        ;;
      "WARN")
        echo -e "${YELLOW}[WARN]${NC} ${timestamp}: ${message}"
        ;;
      "ERROR")
        echo -e "${RED}[ERROR]${NC} ${timestamp}: ${message}"
        ;;
      "DEBUG")
        echo -e "${BLUE}[DEBUG]${NC} ${timestamp}: ${message}"
        ;;
      *)
        echo -e "${timestamp}: ${message}"
        ;;
    esac
  fi
  
  # Запись в лог-файл
  echo "[${level}] ${timestamp}: ${message}" >> "${LOG_FILE}"
  
  # Запись в отчет
  echo "[${level}] ${timestamp}: ${message}" >> "${REPORT_FILE}"
}

# Функция для отправки уведомлений
send_notification() {
  local subject=$1
  local message=$2
  
  # Пропускаем отправку, если уведомления отключены
  if [ "${SEND_NOTIFICATIONS}" != true ]; then
    return 0
  fi
  
  log_message "INFO" "Отправка уведомления: ${subject}"
  
  # Отправка по электронной почте (если настроена)
  if [ -n "${NOTIFICATION_EMAIL}" ]; then
    echo "${message}" | mail -s "${subject}" "${NOTIFICATION_EMAIL}"
  fi
  
  # Отправка в Telegram (если настроен)
  if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="${subject}: ${message}" \
      -d parse_mode="HTML" > /dev/null
  fi
}

# Проверка наличия необходимых зависимостей
check_dependencies() {
  local missing_deps=0
  
  # Проверяем наличие docker
  if ! command -v docker &> /dev/null; then
    log_message "ERROR" "Отсутствует утилита docker. Убедитесь, что Docker установлен и доступен"
    missing_deps=1
  fi
  
  # Проверяем наличие curl
  if ! command -v curl &> /dev/null; then
    log_message "ERROR" "Отсутствует утилита curl. Установите её с помощью 'apt-get install curl'"
    missing_deps=1
  fi
  
  # Проверяем наличие jq
  if ! command -v jq &> /dev/null; then
    log_message "ERROR" "Отсутствует утилита jq. Установите её с помощью 'apt-get install jq'"
    missing_deps=1
  fi
  
  # Проверяем наличие netstat
  if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
    log_message "ERROR" "Отсутствуют утилиты netstat/ss. Установите их с помощью 'apt-get install net-tools' или 'apt-get install iproute2'"
    missing_deps=1
  fi
  
  if [ ${missing_deps} -ne 0 ]; then
    return 1
  fi
  
  return 0
}

# Функция для получения списка контейнеров из docker-compose
get_container_list() {
  # Проверяем существование docker-compose файла
  if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_message "ERROR" "Docker Compose файл не найден: ${DOCKER_COMPOSE_FILE}"
    return 1
  fi
  
  # Получаем список всех контейнеров из docker-compose
  local containers=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q)
  
  if [ -z "${containers}" ]; then
    log_message "WARN" "Не найдено запущенных контейнеров из docker-compose"
    return 1
  fi
  
  # Получаем имена контейнеров
  for container in ${containers}; do
    docker inspect --format='{{.Name}}' "${container}" | sed 's/^\///'
  done
  
  return 0
}

# Функция для проверки состояния контейнера
check_container_health() {
  local container_name=$1
  
  log_message "INFO" "Проверка состояния контейнера: ${container_name}"
  
  # Проверяем существование контейнера
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log_message "ERROR" "Контейнер ${container_name} не существует"
    return 1
  fi
  
  # Проверяем статус контейнера
  local status=$(docker inspect --format='{{.State.Status}}' "${container_name}")
  local running=false
  
  if [ "${status}" = "running" ]; then
    running=true
    log_message "INFO" "Контейнер ${container_name} запущен"
  else
    log_message "ERROR" "Контейнер ${container_name} не запущен (статус: ${status})"
  fi
  
  # Проверяем healthcheck, если контейнер запущен
  if [ "${running}" = true ]; then
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_name}")
    
    if [ "${health}" = "none" ]; then
      log_message "INFO" "Контейнер ${container_name} не имеет healthcheck"
    elif [ "${health}" = "healthy" ]; then
      log_message "INFO" "Контейнер ${container_name} здоров (${health})"
      return 0
    elif [ "${health}" = "starting" ]; then
      log_message "WARN" "Контейнер ${container_name} в процессе запуска"
      return 2
    else
      log_message "ERROR" "Контейнер ${container_name} имеет проблемы со здоровьем (${health})"
      return 1
    fi
  fi
  
  # Если контейнер не запущен, возвращаем ошибку
  if [ "${running}" = false ]; then
    return 1
  fi
  
  # Если контейнер запущен, но не имеет healthcheck, считаем его здоровым
  return 0
}

# Функция для проверки доступности сервиса через HTTP
check_http_service() {
  local container_name=$1
  local port=$2
  local endpoint=${3:-"/"}
  local expected_status=${4:-200}
  
  log_message "INFO" "Проверка HTTP сервиса ${container_name} на порту ${port} по пути ${endpoint}"
  
  # Получаем IP адрес контейнера
  local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}")
  
  if [ -z "${container_ip}" ]; then
    log_message "ERROR" "Не удалось получить IP адрес контейнера ${container_name}"
    return 1
  fi
  
  # Проверяем доступность сервиса
  local http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://${container_ip}:${port}${endpoint}")
  
  if [ "${http_status}" = "${expected_status}" ]; then
    log_message "INFO" "HTTP сервис ${container_name} доступен (статус: ${http_status})"
    return 0
  else
    log_message "ERROR" "HTTP сервис ${container_name} недоступен (статус: ${http_status}, ожидался: ${expected_status})"
    return 1
  fi
}

# Функция для проверки подключения к базе данных PostgreSQL
check_postgres_connection() {
  local container_name=$1
  local db_name=$2
  local db_user=$3
  local db_password=$4
  
  log_message "INFO" "Проверка подключения к PostgreSQL в контейнере ${container_name}"
  
  # Выполняем простой запрос к PostgreSQL
  local result=$(docker exec "${container_name}" psql -U "${db_user}" -d "${db_name}" -c "SELECT version();" 2>&1)
  
  if [ $? -eq 0 ]; then
    log_message "INFO" "Подключение к PostgreSQL успешно"
    return 0
  else
    log_message "ERROR" "Ошибка подключения к PostgreSQL: ${result}"
    return 1
  fi
}

# Функция для проверки подключения к базе данных MariaDB/MySQL
check_mysql_connection() {
  local container_name=$1
  local db_name=$2
  local db_user=$3
  local db_password=$4
  
  log_message "INFO" "Проверка подключения к MariaDB в контейнере ${container_name}"
  
  # Выполняем простой запрос к MariaDB
  local result=$(docker exec "${container_name}" mysql -u "${db_user}" -p"${db_password}" -e "SELECT VERSION();" "${db_name}" 2>&1)
  
  if [ $? -eq 0 ]; then
    log_message "INFO" "Подключение к MariaDB успешно"
    return 0
  else
    log_message "ERROR" "Ошибка подключения к MariaDB: ${result}"
    return 1
  fi
}

# Функция для проверки сетевых подключений между контейнерами
check_network_connectivity() {
  local source_container=$1
  local target_container=$2
  local target_port=$3
  
  log_message "INFO" "Проверка сетевой связности ${source_container} -> ${target_container}:${target_port}"
  
  # Получаем IP адрес целевого контейнера
  local target_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${target_container}")
  
  if [ -z "${target_ip}" ]; then
    log_message "ERROR" "Не удалось получить IP адрес контейнера ${target_container}"
    return 1
  fi
  
  # Проверяем доступность целевого контейнера через nc или wget
  local result=$(docker exec "${source_container}" timeout 5 bash -c "echo > /dev/tcp/${target_ip}/${target_port}" 2>&1)
  
  if [ $? -eq 0 ]; then
    log_message "INFO" "Сетевое соединение ${source_container} -> ${target_container}:${target_port} установлено"
    return 0
  else
    log_message "ERROR" "Сетевое соединение ${source_container} -> ${target_container}:${target_port} недоступно: ${result}"
    return 1
  fi
}

# Функция для проверки объема свободного места на дисках
check_disk_space() {
  local min_free_percent=${1:-10}
  
  log_message "INFO" "Проверка свободного места на дисках (минимум: ${min_free_percent}%)"
  
  # Получаем информацию о файловых системах
  local filesystems=$(df -h --output=target,size,used,avail,pcent | grep -v "Filesystem" | grep -v "tmpfs" | grep -v "udev")
  
  local has_low_space=false
  
  # Проверяем каждую файловую систему
  echo "${filesystems}" | while read -r line; do
    local mount=$(echo "${line}" | awk '{print $1}')
    local total=$(echo "${line}" | awk '{print $2}')
    local used=$(echo "${line}" | awk '{print $3}')
    local avail=$(echo "${line}" | awk '{print $4}')
    local used_percent=$(echo "${line}" | awk '{print $5}' | sed 's/%//')
    local free_percent=$((100 - used_percent))
    
    if [ ${free_percent} -lt ${min_free_percent} ]; then
      log_message "ERROR" "Критически мало свободного места на ${mount}: ${free_percent}% (${avail} из ${total})"
      has_low_space=true
    else
      log_message "INFO" "Достаточно свободного места на ${mount}: ${free_percent}% (${avail} из ${total})"
    fi
  done
  
  if [ "${has_low_space}" = true ]; then
    return 1
  else
    return 0
  fi
}

# Функция для проверки использования Docker volumes
check_docker_volumes() {
  log_message "INFO" "Проверка Docker томов"
  
  # Получаем список всех томов
  local volumes=$(docker volume ls --quiet)
  
  if [ -z "${volumes}" ]; then
    log_message "WARN" "Docker томы не найдены"
    return 0
  fi
  
  local has_errors=false
  
  # Проверяем каждый том
  for volume in ${volumes}; do
    # Получаем информацию о томе
    local volume_info=$(docker volume inspect "${volume}")
    
    # Проверяем, что том используется контейнером
    local is_used=$(echo "${volume_info}" | jq '.[0].UsageData.RefCount // 0')
    
    if [ "${is_used}" = "0" ]; then
      log_message "WARN" "Docker том ${volume} не используется ни одним контейнером"
    fi
    
    # Проверяем доступность директории тома
    local mountpoint=$(echo "${volume_info}" | jq -r '.[0].Mountpoint')
    
    if [ ! -d "${mountpoint}" ]; then
      log_message "ERROR" "Точка монтирования тома ${volume} не существует: ${mountpoint}"
      has_errors=true
    elif [ ! -w "${mountpoint}" ]; then
      log_message "ERROR" "Точка монтирования тома ${volume} недоступна для записи: ${mountpoint}"
      has_errors=true
    else
      log_message "INFO" "Том ${volume} доступен в ${mountpoint}"
    fi
  done
  
  if [ "${has_errors}" = true ]; then
    return 1
  else
    return 0
  fi
}

# Функция для проверки ресурсов системы (CPU, RAM)
check_system_resources() {
  log_message "INFO" "Проверка системных ресурсов"
  
  # Проверка загрузки CPU
  local cpu_load=$(cat /proc/loadavg | awk '{print $1}')
  local cpu_cores=$(nproc)
  local cpu_load_percent=$(echo "${cpu_load} ${cpu_cores}" | awk '{printf "%.2f", $1 / $2 * 100}')
  
  if (( $(echo "${cpu_load_percent} > 80" | bc -l) )); then
    log_message "ERROR" "Высокая загрузка CPU: ${cpu_load_percent}% (${cpu_load} на ${cpu_cores} ядрах)"
  else
    log_message "INFO" "Загрузка CPU в норме: ${cpu_load_percent}% (${cpu_load} на ${cpu_cores} ядрах)"
  fi
  
  # Проверка использования памяти
  local mem_total=$(free -m | grep "Mem:" | awk '{print $2}')
  local mem_used=$(free -m | grep "Mem:" | awk '{print $3}')
  local mem_used_percent=$(echo "${mem_used} ${mem_total}" | awk '{printf "%.2f", $1 / $2 * 100}')
  
  if (( $(echo "${mem_used_percent} > 90" | bc -l) )); then
    log_message "ERROR" "Критически высокое использование памяти: ${mem_used_percent}% (${mem_used}MB/${mem_total}MB)"
    return 1
  elif (( $(echo "${mem_used_percent} > 80" | bc -l) )); then
    log_message "WARN" "Высокое использование памяти: ${mem_used_percent}% (${mem_used}MB/${mem_total}MB)"
  else
    log_message "INFO" "Использование памяти в норме: ${mem_used_percent}% (${mem_used}MB/${mem_total}MB)"
  fi
  
  # Проверка использования swap
  local swap_total=$(free -m | grep "Swap:" | awk '{print $2}')
  
  if [ "${swap_total}" -eq 0 ]; then
    log_message "WARN" "Swap не настроен на сервере"
  else
    local swap_used=$(free -m | grep "Swap:" | awk '{print $3}')
    local swap_used_percent=$(echo "${swap_used} ${swap_total}" | awk '{printf "%.2f", $1 / $2 * 100}')
    
    if (( $(echo "${swap_used_percent} > 50" | bc -l) )); then
      log_message "WARN" "Высокое использование Swap: ${swap_used_percent}% (${swap_used}MB/${swap_total}MB)"
    else
      log_message "INFO" "Использование Swap в норме: ${swap_used_percent}% (${swap_used}MB/${swap_total}MB)"
    fi
  fi
  
  return 0
}
