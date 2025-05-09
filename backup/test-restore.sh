#!/bin/bash

# =================================================================
# Скрипт для автоматического тестирования восстановления из резервных копий
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
BACKUP_ROOT="/opt/backups"
LOG_FILE="/var/log/restore-test.log"
TEST_DIR="/tmp/restore-test"
DOCKER_RESTORE_SCRIPT="/opt/docker-restore.sh"
NOTIFICATION_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
SEND_NOTIFICATIONS=true
TEST_POSTGRES=true
TEST_MYSQL=true
TEST_N8N=true

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
    "DEBUG")
      echo -e "${BLUE}[DEBUG]${NC} ${timestamp}: ${message}"
      ;;
    *)
      echo -e "${timestamp}: ${message}"
      ;;
  esac
  
  # Запись в лог-файл
  echo "[${level}] ${timestamp}: ${message}" >> "${LOG_FILE}"
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

# Функция для поиска последней резервной копии
find_latest_backup() {
  log_message "INFO" "Поиск последней резервной копии в ${BACKUP_ROOT}"
  
  # Проверка существования директории с резервными копиями
  if [ ! -d "${BACKUP_ROOT}" ]; then
    log_message "ERROR" "Директория с резервными копиями не существует: ${BACKUP_ROOT}"
    return 1
  fi
  
  # Поиск последней резервной копии по дате создания
  local latest_backup=$(find "${BACKUP_ROOT}" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r | head -1)
  
  if [ -z "${latest_backup}" ]; then
    log_message "ERROR" "Резервные копии не найдены в ${BACKUP_ROOT}"
    return 1
  fi
  
  echo "${latest_backup}"
  return 0
}

# Функция для проверки целостности резервной копии
verify_backup() {
  local backup_dir=$1
  
  log_message "INFO" "Проверка целостности резервной копии: ${backup_dir}"
  
  # Проверка наличия файла метаданных
  if [ ! -f "${backup_dir}/metadata.json" ]; then
    log_message "ERROR" "Файл метаданных отсутствует: ${backup_dir}/metadata.json"
    return 1
  fi
  
  # Проверка наличия директории с томами
  if [ ! -d "${backup_dir}/volumes" ]; then
    log_message "ERROR" "Директория с томами отсутствует: ${backup_dir}/volumes"
    return 1
  fi
  
  # Получение информации о сжатии из метаданных
  local compressed=$(grep -o '"compressed": *[^,}]*' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d ' ')
  
  # Получение списка томов из метаданных
  local volumes_json=$(grep -o '"volumes_included": *\[[^]]*\]' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d '[]" ')
  local volumes=($(echo ${volumes_json} | tr ',' ' '))
  
  # Проверка наличия критически важных томов
  local critical_volumes=(
    "n8n_postgres_data"
    "n8n_data"
    "wordpress_db_data"
    "qdrant_storage"
  )
  
  for volume in "${critical_volumes[@]}"; do
    if ! echo "${volumes_json}" | grep -q "${volume}"; then
      log_message "WARN" "Критически важный том ${volume} отсутствует в резервной копии"
    else
      # Проверка наличия файла или директории для тома
      if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
        if [ ! -f "${backup_dir}/volumes/${volume}.tar.gz" ]; then
          log_message "ERROR" "Архив тома ${volume} отсутствует в резервной копии"
          return 1
        fi
      else
        if [ ! -d "${backup_dir}/volumes/${volume}" ]; then
          log_message "ERROR" "Директория тома ${volume} отсутствует в резервной копии"
          return 1
        fi
      fi
    fi
  done
  
  log_message "INFO" "Резервная копия успешно прошла проверку целостности"
  return 0
}

# Функция для подготовки тестового окружения
prepare_test_environment() {
  log_message "INFO" "Подготовка тестового окружения"
  
  # Удаление старого тестового окружения, если оно существует
  if [ -d "${TEST_DIR}" ]; then
    log_message "INFO" "Удаление старого тестового окружения"
    rm -rf "${TEST_DIR}"
  fi
  
  # Создание директории для тестового окружения
  mkdir -p "${TEST_DIR}"
  
  if [ $? -ne 0 ]; then
    log_message "ERROR" "Не удалось создать директорию для тестового окружения: ${TEST_DIR}"
    return 1
  fi
  
  log_message "INFO" "Тестовое окружение успешно подготовлено"
  return 0
}

# Функция для тестирования восстановления PostgreSQL
test_postgres_restore() {
  local backup_dir=$1
  
  log_message "INFO" "Тестирование восстановления PostgreSQL"
  
  # Проверка существования резервной копии PostgreSQL
  if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
    if [ ! -f "${backup_dir}/volumes/n8n_postgres_data.tar.gz" ]; then
      log_message "ERROR" "Архив резервной копии PostgreSQL не найден"
      return 1
    fi
    
    # Распаковка резервной копии во временную директорию
    log_message "INFO" "Распаковка резервной копии PostgreSQL"
    mkdir -p "${TEST_DIR}/postgres"
    tar -xzf "${backup_dir}/volumes/n8n_postgres_data.tar.gz" -C "${TEST_DIR}/postgres"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось распаковать резервную копию PostgreSQL"
      return 1
    fi
  else
    if [ ! -d "${backup_dir}/volumes/n8n_postgres_data" ]; then
      log_message "ERROR" "Директория резервной копии PostgreSQL не найдена"
      return 1
    fi
    
    # Копирование резервной копии во временную директорию
    log_message "INFO" "Копирование резервной копии PostgreSQL"
    cp -r "${backup_dir}/volumes/n8n_postgres_data" "${TEST_DIR}/postgres"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось скопировать резервную копию PostgreSQL"
      return 1
    fi
  fi
  
  # Проверка наличия основных файлов PostgreSQL
  if [ ! -f "${TEST_DIR}/postgres/PG_VERSION" ]; then
    log_message "ERROR" "Файл PG_VERSION не найден в резервной копии PostgreSQL"
    return 1
  fi
  
  log_message "INFO" "Тестирование восстановления PostgreSQL успешно завершено"
  return 0
}

# Функция для тестирования восстановления MySQL/MariaDB
test_mysql_restore() {
  local backup_dir=$1
  
  log_message "INFO" "Тестирование восстановления MySQL/MariaDB"
  
  # Проверка существования резервной копии MySQL/MariaDB
  if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
    if [ ! -f "${backup_dir}/volumes/wordpress_db_data.tar.gz" ]; then
      log_message "ERROR" "Архив резервной копии MySQL/MariaDB не найден"
      return 1
    fi
    
    # Распаковка резервной копии во временную директорию
    log_message "INFO" "Распаковка резервной копии MySQL/MariaDB"
    mkdir -p "${TEST_DIR}/mysql"
    tar -xzf "${backup_dir}/volumes/wordpress_db_data.tar.gz" -C "${TEST_DIR}/mysql"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось распаковать резервную копию MySQL/MariaDB"
      return 1
    fi
  else
    if [ ! -d "${backup_dir}/volumes/wordpress_db_data" ]; then
      log_message "ERROR" "Директория резервной копии MySQL/MariaDB не найдена"
      return 1
    fi
    
    # Копирование резервной копии во временную директорию
    log_message "INFO" "Копирование резервной копии MySQL/MariaDB"
    cp -r "${backup_dir}/volumes/wordpress_db_data" "${TEST_DIR}/mysql"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось скопировать резервную копию MySQL/MariaDB"
      return 1
    fi
  fi
  
  # Проверка наличия основных файлов MySQL/MariaDB
  if [ ! -d "${TEST_DIR}/mysql/mysql" ] && [ ! -d "${TEST_DIR}/mysql/data" ]; then
    log_message "ERROR" "Файлы базы данных не найдены в резервной копии MySQL/MariaDB"
    return 1
  fi
  
  log_message "INFO" "Тестирование восстановления MySQL/MariaDB успешно завершено"
  return 0
}

# Функция для тестирования восстановления n8n
test_n8n_restore() {
  local backup_dir=$1
  
  log_message "INFO" "Тестирование восстановления n8n"
  
  # Проверка существования резервной копии n8n
  if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
    if [ ! -f "${backup_dir}/volumes/n8n_data.tar.gz" ]; then
      log_message "ERROR" "Архив резервной копии n8n не найден"
      return 1
    fi
    
    # Распаковка резервной копии во временную директорию
    log_message "INFO" "Распаковка резервной копии n8n"
    mkdir -p "${TEST_DIR}/n8n"
    tar -xzf "${backup_dir}/volumes/n8n_data.tar.gz" -C "${TEST_DIR}/n8n"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось распаковать резервную копию n8n"
      return 1
    fi
  else
    if [ ! -d "${backup_dir}/volumes/n8n_data" ]; then
      log_message "ERROR" "Директория резервной копии n8n не найдена"
      return 1
    fi
    
    # Копирование резервной копии во временную директорию
    log_message "INFO" "Копирование резервной копии n8n"
    cp -r "${backup_dir}/volumes/n8n_data" "${TEST_DIR}/n8n"
    
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось скопировать резервную копию n8n"
      return 1
    fi
  fi
  
  # Проверка наличия основных файлов n8n
  if [ ! -f "${TEST_DIR}/n8n/.n8ndbmigration" ] && [ ! -d "${TEST_DIR}/n8n/database" ]; then
    log_message "ERROR" "Файлы n8n не найдены в резервной копии"
    return 1
  fi
  
  log_message "INFO" "Тестирование восстановления n8n успешно завершено"
  return 0
}

# Функция для очистки после тестирования
cleanup_test_environment() {
  log_message "INFO" "Очистка тестового окружения"
  
  if [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
    
    if [ $? -eq 0 ]; then
      log_message "INFO" "Тестовое окружение успешно очищено"
    else
      log_message "WARN" "Не удалось очистить тестовое окружение"
    fi
  fi
  
  return 0
}

# Основная функция для тестирования восстановления
test_restore() {
  log_message "INFO" "=== Начало тестирования восстановления из резервной копии ==="
  
  # Поиск последней резервной копии
  local backup_dir=$(find_latest_backup)
  
  if [ -z "${backup_dir}" ]; then
    log_message "ERROR" "Не удалось найти резервную копию для тестирования"
    send_notification "Ошибка тестирования восстановления" "Не удалось найти резервную копию для тестирования"
    return 1
  fi
  
  log_message "INFO" "Найдена резервная копия для тестирования: ${backup_dir}"
  
  # Проверка целостности резервной копии
  if ! verify_backup "${backup_dir}"; then
    log_message "ERROR" "Резервная копия не прошла проверку целостности"
    send_notification "Ошибка тестирования восстановления" "Резервная копия не прошла проверку целостности: ${backup_dir}"
    return 1
  fi
  
  # Подготовка тестового окружения
  if ! prepare_test_environment; then
    log_message "ERROR" "Не удалось подготовить тестовое окружение"
    send_notification "Ошибка тестирования восстановления" "Не удалось подготовить тестовое окружение"
    return 1
  fi
  
  # Получение информации о сжатии из метаданных
  compressed=$(grep -o '"compressed": *[^,}]*' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d ' ')
  
  # Выполнение тестов восстановления
  local test_errors=0
  
  if [ "${TEST_POSTGRES}" = true ]; then
    if ! test_postgres_restore "${backup_dir}"; then
      log_message "ERROR" "Тестирование восстановления PostgreSQL завершилось с ошибкой"
      test_errors=$((test_errors + 1))
    fi
  fi
  
  if [ "${TEST_MYSQL}" = true ]; then
    if ! test_mysql_restore "${backup_dir}"; then
      log_message "ERROR" "Тестирование восстановления MySQL/MariaDB завершилось с ошибкой"
      test_errors=$((test_errors + 1))
    fi
  fi
  
  if [ "${TEST_N8N}" = true ]; then
    if ! test_n8n_restore "${backup_dir}"; then
      log_message "ERROR" "Тестирование восстановления n8n завершилось с ошибкой"
      test_errors=$((test_errors + 1))
    fi
  fi
  
  # Очистка тестового окружения
  cleanup_test_environment
  
  # Итоговый результат
  if [ ${test_errors} -eq 0 ]; then
    log_message "INFO" "=== Тестирование восстановления из резервной копии успешно завершено ==="
    send_notification "Тестирование восстановления успешно" "Резервная копия ${backup_dir} прошла все тесты восстановления"
    return 0
  else
    log_message "ERROR" "=== Тестирование восстановления из резервной копии завершилось с ошибками (${test_errors}) ==="
    send_notification "Тестирование восстановления завершилось с ошибками" "Резервная копия ${backup_dir} не прошла ${test_errors} тестов восстановления"
    return 1
  fi
}

# Функция для настройки автоматического запуска
setup_cron() {
  log_message "INFO" "Настройка автоматического запуска тестирования восстановления"
  
  # Создание временного cron-файла
  cat > "/tmp/restore-test.cron" << EOF
# Еженедельное тестирование восстановления по воскресеньям в 4:00
0 4 * * 0 root ${0} --test > /dev/null 2>&1
EOF
  
  # Установка cron-задания
  mv "/tmp/restore-test.cron" "/etc/cron.d/restore-test"
  chmod 644 "/etc/cron.d/restore-test"
  
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
  log_message "INFO" "Настройка уведомлений о результатах тестирования"
  
  echo "Хотите настроить уведомления о результатах тестирования восстановления? [y/N] "
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
    cat > "/opt/restore-test.conf" << EOF
# Конфигурация системы тестирования восстановления
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
SEND_NOTIFICATIONS=true
TEST_POSTGRES=true
TEST_MYSQL=true
TEST_N8N=true
EOF
    
    log_message "INFO" "Настройки уведомлений сохранены в /opt/restore-test.conf"
  else
    SEND_NOTIFICATIONS=false
  fi
  
  return 0
}

# Обработка аргументов командной строки
case "$1" in
  --test)
    # Загрузка конфигурации, если она существует
    if [ -f "/opt/restore-test.conf" ]; then
      source "/opt/restore-test.conf"
    fi
    
    # Запуск тестирования восстановления
    test_restore
    exit $?
    ;;
  --setup)
    # Настройка уведомлений
    setup_notifications
    
    # Настройка автоматического запуска
    setup_cron
    
    log_message "INFO" "Настройка системы тестирования восстановления завершена"
    exit 0
    ;;
  --help)
    echo "Использование: $0 [ОПЦИЯ]"
    echo "  --test    Запустить тестирование восстановления"
    echo "  --setup   Настроить автоматическое тестирование"
    echo "  --help    Показать эту справку"
    exit 0
    ;;
  *)
    if [ -t 0 ]; then
      # Интерактивный режим
      echo -e "${GREEN}=== Система тестирования восстановления из резервных копий ===${NC}"
      echo "1) Запустить тестирование восстановления"
      echo "2) Настроить автоматическое тестирование"
      
      read -p "Выберите действие [1-2]: " choice
      
      case $choice in
        1)
          test_restore
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
      # По умолчанию запускаем тестирование
      test_restore
      exit $?
    fi
    ;;
esac
