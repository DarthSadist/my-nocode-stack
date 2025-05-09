#!/bin/bash

# =================================================================
# Скрипт для автоматического обслуживания системы
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
LOG_DIR="/var/log"
MAINTENANCE_LOG="${LOG_DIR}/system-maintenance.log"
BACKUP_DIR="/opt/backups"
RETENTION_DAYS=30
DISK_THRESHOLD=80
DOCKER_PRUNE=true
CLEAN_LOGS=true
OPTIMIZE_DB=true
STACK_DIR="/home/den/my-nocode-stack"
NOTIFICATION_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
SEND_NOTIFICATIONS=true

# Функция для логирования
log_message() {
  local level=$1
  local message=$2
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Вывод в консоль
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
    "STEP")
      echo -e "\n${BLUE}=== ${message} ===${NC}"
      ;;
    *)
      echo -e "${timestamp}: ${message}"
      ;;
  esac
  
  # Запись в лог-файл
  echo "[${level}] ${timestamp}: ${message}" >> "${MAINTENANCE_LOG}"
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

# Функция для проверки дискового пространства
check_disk_space() {
  log_message "STEP" "Проверка дискового пространства"
  
  # Получение информации о дисковом пространстве
  local df_output=$(df -h / | tail -n 1)
  local disk_usage=$(echo "${df_output}" | awk '{print $5}' | tr -d '%')
  local disk_free=$(echo "${df_output}" | awk '{print $4}')
  local disk_total=$(echo "${df_output}" | awk '{print $2}')
  
  log_message "INFO" "Использование диска: ${disk_usage}% (свободно: ${disk_free}, всего: ${disk_total})"
  
  # Проверка превышения порога
  if [ "${disk_usage}" -gt "${DISK_THRESHOLD}" ]; then
    log_message "WARN" "Использование диска превышает порог (${DISK_THRESHOLD}%)"
    send_notification "Предупреждение о дисковом пространстве" "Использование диска достигло ${disk_usage}% (свободно: ${disk_free})"
    return 1
  fi
  
  return 0
}

# Функция для очистки старых резервных копий
clean_old_backups() {
  log_message "STEP" "Очистка старых резервных копий"
  
  # Проверка существования директории с резервными копиями
  if [ ! -d "${BACKUP_DIR}" ]; then
    log_message "WARN" "Директория с резервными копиями не существует: ${BACKUP_DIR}"
    return 1
  fi
  
  # Поиск и удаление резервных копий старше заданного срока
  log_message "INFO" "Поиск резервных копий старше ${RETENTION_DAYS} дней"
  local old_backups=$(find "${BACKUP_DIR}" -maxdepth 1 -type d -name "????-??-??_??-??-??" -mtime +${RETENTION_DAYS})
  
  if [ -z "${old_backups}" ]; then
    log_message "INFO" "Старые резервные копии не найдены"
    return 0
  fi
  
  # Подсчет размера удаляемых копий
  local total_size=0
  for backup in ${old_backups}; do
    local size=$(du -sh "${backup}" | awk '{print $1}')
    log_message "INFO" "Найдена старая резервная копия: ${backup} (размер: ${size})"
    total_size=$((total_size + $(du -sk "${backup}" | awk '{print $1}')))
  done
  
  # Перевод размера в человекочитаемый формат
  local human_size=$(numfmt --to=iec --suffix=B ${total_size}K)
  
  # Удаление старых резервных копий
  log_message "INFO" "Удаление ${#old_backups[@]} старых резервных копий (общий размер: ${human_size})"
  
  for backup in ${old_backups}; do
    log_message "INFO" "Удаление резервной копии: ${backup}"
    rm -rf "${backup}"
    
    if [ $? -eq 0 ]; then
      log_message "INFO" "Резервная копия успешно удалена: ${backup}"
    else
      log_message "ERROR" "Не удалось удалить резервную копию: ${backup}"
    fi
  done
  
  return 0
}

# Функция для очистки Docker
clean_docker() {
  log_message "STEP" "Очистка Docker"
  
  # Проверка запущен ли Docker
  if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    log_message "WARN" "Docker недоступен или не запущен"
    return 1
  fi
  
  # Очистка неиспользуемых контейнеров
  log_message "INFO" "Удаление остановленных контейнеров"
  docker container prune -f > /dev/null
  
  # Очистка неиспользуемых образов
  log_message "INFO" "Удаление неиспользуемых образов"
  docker image prune -f > /dev/null
  
  # Очистка неиспользуемых томов
  log_message "INFO" "Удаление неиспользуемых томов"
  docker volume prune -f > /dev/null
  
  # Очистка неиспользуемых сетей
  log_message "INFO" "Удаление неиспользуемых сетей"
  docker network prune -f > /dev/null
  
  # Очистка всей системы
  log_message "INFO" "Общая очистка системы Docker"
  docker system prune -f > /dev/null
  
  return 0
}

# Функция для очистки логов
clean_logs() {
  log_message "STEP" "Очистка логов"
  
  # Проверка существования директории с логами
  if [ ! -d "${LOG_DIR}" ]; then
    log_message "WARN" "Директория с логами не существует: ${LOG_DIR}"
    return 1
  fi
  
  # Очистка старых сжатых логов
  log_message "INFO" "Удаление старых сжатых логов (старше ${RETENTION_DAYS} дней)"
  find "${LOG_DIR}" -name "*.gz" -mtime +${RETENTION_DAYS} -delete
  
  # Очистка больших логов (более 100 МБ)
  log_message "INFO" "Очистка больших лог-файлов (более 100 МБ)"
  find "${LOG_DIR}" -type f -size +100M | while read -r logfile; do
    log_message "INFO" "Очистка большого лог-файла: ${logfile}"
    
    # Сохранение последних 1000 строк лога
    if [ -f "${logfile}" ]; then
      tail -n 1000 "${logfile}" > "${logfile}.tmp"
      mv "${logfile}.tmp" "${logfile}"
      log_message "INFO" "Лог-файл очищен: ${logfile}"
    fi
  done
  
  # Очистка логов Docker
  if [ -d "/var/lib/docker/containers" ]; then
    log_message "INFO" "Очистка логов Docker"
    find /var/lib/docker/containers -name "*.log" -size +20M -exec truncate -s 0 {} \;
  fi
  
  return 0
}

# Функция для оптимизации баз данных
optimize_databases() {
  log_message "STEP" "Оптимизация баз данных"
  
  # Проверка существования скриптов оптимизации
  local postgres_script="${STACK_DIR}/backup/postgres-optimization.sh"
  local mariadb_script="${STACK_DIR}/backup/mariadb-optimization.sh"
  
  # Оптимизация PostgreSQL
  if [ -f "${postgres_script}" ]; then
    log_message "INFO" "Запуск скрипта оптимизации PostgreSQL"
    bash "${postgres_script}" > /dev/null
    
    if [ $? -eq 0 ]; then
      log_message "INFO" "PostgreSQL успешно оптимизирован"
    else
      log_message "WARN" "Не удалось оптимизировать PostgreSQL"
    fi
  else
    log_message "WARN" "Скрипт оптимизации PostgreSQL не найден: ${postgres_script}"
  fi
  
  # Оптимизация MariaDB
  if [ -f "${mariadb_script}" ]; then
    log_message "INFO" "Запуск скрипта оптимизации MariaDB"
    bash "${mariadb_script}" > /dev/null
    
    if [ $? -eq 0 ]; then
      log_message "INFO" "MariaDB успешно оптимизирован"
    else
      log_message "WARN" "Не удалось оптимизировать MariaDB"
    fi
  else
    log_message "WARN" "Скрипт оптимизации MariaDB не найден: ${mariadb_script}"
  fi
  
  return 0
}

# Функция для проверки производительности системы
check_performance() {
  log_message "STEP" "Проверка производительности системы"
  
  # Проверка загрузки CPU
  local cpu_load=$(uptime | awk -F'[a-z]:' '{ print $2}' | awk -F',' '{ print $1}' | tr -d ' ')
  log_message "INFO" "Средняя загрузка CPU: ${cpu_load}"
  
  # Проверка использования памяти
  local mem_total=$(free -m | awk 'NR==2{print $2}')
  local mem_used=$(free -m | awk 'NR==2{print $3}')
  local mem_usage=$((mem_used * 100 / mem_total))
  log_message "INFO" "Использование памяти: ${mem_usage}% (${mem_used}MB из ${mem_total}MB)"
  
  # Проверка нагрузки на диск
  local disk_io=$(iostat -x | grep 'sda' | awk '{print $14}')
  if [ -n "${disk_io}" ]; then
    log_message "INFO" "Нагрузка на диск: ${disk_io}% утилизации"
  fi
  
  # Проверка загруженных контейнеров
  if command -v docker &> /dev/null; then
    log_message "INFO" "Статистика контейнеров:"
    docker stats --no-stream --format "{{.Name}}: CPU={{.CPUPerc}}, MEM={{.MemPerc}}" | while read -r stats; do
      log_message "INFO" "${stats}"
    done
  fi
  
  # Предупреждение о высокой нагрузке
  if (( $(echo "${cpu_load} > 2" | bc -l) )) || [ "${mem_usage}" -gt 90 ]; then
    log_message "WARN" "Обнаружена высокая нагрузка на систему"
    send_notification "Предупреждение о производительности" "Высокая нагрузка: CPU=${cpu_load}, MEM=${mem_usage}%"
  fi
  
  return 0
}

# Функция для настройки cron
setup_cron() {
  log_message "INFO" "Настройка автоматического обслуживания"
  
  # Создание временного cron-файла
  cat > "/tmp/system-maintenance.cron" << EOF
# Ежедневное обслуживание системы в 3:00
0 3 * * * root ${0} --run > /dev/null 2>&1
EOF
  
  # Установка cron-задания
  mv "/tmp/system-maintenance.cron" "/etc/cron.d/system-maintenance"
  chmod 644 "/etc/cron.d/system-maintenance"
  
  if [ $? -eq 0 ]; then
    log_message "INFO" "Cron-задание успешно настроено"
    return 0
  else
    log_message "ERROR" "Не удалось настроить cron-задание"
    return 1
  fi
}

# Функция для настройки уведомлений
setup_notifications() {
  log_message "INFO" "Настройка уведомлений о результатах обслуживания"
  
  echo "Хотите настроить уведомления о результатах обслуживания? [y/N] "
  read -r setup_notif
  
  if [[ "${setup_notif}" =~ ^[Yy]$ ]]; then
    echo "Хотите получать уведомления по электронной почте? [y/N] "
    read -r setup_email
    
    if [[ "${setup_email}" =~ ^[Yy]$ ]]; then
      echo "Введите email для уведомлений: "
      read -r email
      NOTIFICATION_EMAIL="${email}"
    fi
    
    echo "Хотите получать уведомления через Telegram? [y/N] "
    read -r setup_telegram
    
    if [[ "${setup_telegram}" =~ ^[Yy]$ ]]; then
      echo "Введите токен Telegram-бота: "
      read -r bot_token
      echo "Введите ID чата: "
      read -r chat_id
      
      TELEGRAM_BOT_TOKEN="${bot_token}"
      TELEGRAM_CHAT_ID="${chat_id}"
    fi
    
    # Сохранение настроек уведомлений
    cat > "/opt/system-maintenance.conf" << EOF
# Конфигурация системы обслуживания
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
SEND_NOTIFICATIONS=true
RETENTION_DAYS=${RETENTION_DAYS}
DISK_THRESHOLD=${DISK_THRESHOLD}
DOCKER_PRUNE=${DOCKER_PRUNE}
CLEAN_LOGS=${CLEAN_LOGS}
OPTIMIZE_DB=${OPTIMIZE_DB}
EOF
    
    log_message "INFO" "Настройки уведомлений сохранены в /opt/system-maintenance.conf"
  else
    SEND_NOTIFICATIONS=false
  fi
  
  return 0
}

# Главная функция обслуживания
run_maintenance() {
  log_message "STEP" "Начало процедуры обслуживания системы"
  
  # Загрузка конфигурации, если она существует
  if [ -f "/opt/system-maintenance.conf" ]; then
    source "/opt/system-maintenance.conf"
  fi
  
  # Проверка дискового пространства
  check_disk_space
  
  # Очистка старых резервных копий
  clean_old_backups
  
  # Очистка Docker если включено
  if [ "${DOCKER_PRUNE}" = true ]; then
    clean_docker
  fi
  
  # Очистка логов если включено
  if [ "${CLEAN_LOGS}" = true ]; then
    clean_logs
  fi
  
  # Оптимизация баз данных если включено
  if [ "${OPTIMIZE_DB}" = true ]; then
    optimize_databases
  fi
  
  # Проверка производительности
  check_performance
  
  log_message "STEP" "Процедура обслуживания системы завершена"
  send_notification "Обслуживание системы завершено" "Все задачи обслуживания успешно выполнены"
  
  return 0
}

# Обработка аргументов командной строки
case "$1" in
  --run)
    # Запуск обслуживания
    run_maintenance
    exit $?
    ;;
  --setup)
    # Настройка уведомлений и расписания
    setup_notifications
    setup_cron
    log_message "INFO" "Настройка системы обслуживания завершена"
    exit 0
    ;;
  --help)
    echo "Использование: $0 [ОПЦИЯ]"
    echo "  --run      Запустить процедуру обслуживания"
    echo "  --setup    Настроить автоматическое обслуживание"
    echo "  --help     Показать эту справку"
    exit 0
    ;;
  *)
    if [ -t 0 ]; then
      # Интерактивный режим
      echo -e "${GREEN}=== Система автоматического обслуживания ===${NC}"
      echo "1) Запустить обслуживание системы"
      echo "2) Настроить автоматическое обслуживание"
      
      read -p "Выберите действие [1-2]: " choice
      
      case $choice in
        1)
          run_maintenance
          exit $?
          ;;
        2)
          setup_notifications
          setup_cron
          exit 0
          ;;
        *)
          echo "Неверный выбор"
          exit 1
          ;;
      esac
    else
      # По умолчанию запускаем обслуживание
      run_maintenance
      exit $?
    fi
    ;;
esac
