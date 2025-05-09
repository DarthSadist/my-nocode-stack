#!/bin/bash

# =================================================================
# Единый скрипт настройки всех компонентов отказоустойчивости
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Директории
BACKUP_DIR="/home/den/my-nocode-stack/backup"
SYSTEM_DIR="/opt"
LOG_FILE="${SYSTEM_DIR}/setup-resilience.log"

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
  echo "[${level}] ${timestamp}: ${message}" >> "${LOG_FILE}"
}

# Функция для установки прав на выполнение скриптов
setup_permissions() {
  log_message "STEP" "Установка прав на выполнение скриптов"
  
  find "${BACKUP_DIR}" -name "*.sh" -type f | while read -r script; do
    log_message "INFO" "Установка прав для ${script}"
    chmod +x "${script}"
    if [ $? -eq 0 ]; then
      log_message "INFO" "Права для ${script} успешно установлены"
    else
      log_message "ERROR" "Не удалось установить права для ${script}"
      return 1
    fi
  done
  
  return 0
}

# Функция для копирования файлов в системную директорию
copy_files_to_system() {
  log_message "STEP" "Копирование скриптов в системную директорию"
  
  # Список файлов для копирования
  local files=(
    "docker-backup.sh"
    "docker-restore.sh"
    "container-monitor.sh"
    "system-diagnostics.sh"
    "system-recovery.sh"
  )
  
  for file in "${files[@]}"; do
    local source="${BACKUP_DIR}/${file}"
    local target="${SYSTEM_DIR}/${file}"
    
    if [ -f "${source}" ]; then
      log_message "INFO" "Копирование ${file} в ${SYSTEM_DIR}"
      cp "${source}" "${target}"
      if [ $? -eq 0 ]; then
        log_message "INFO" "Файл ${file} успешно скопирован"
        chmod +x "${target}"
      else
        log_message "ERROR" "Не удалось скопировать файл ${file}"
        return 1
      fi
    else
      log_message "ERROR" "Исходный файл ${source} не существует"
      return 1
    fi
  done
  
  return 0
}

# Функция для настройки мониторинга контейнеров
setup_container_monitoring() {
  log_message "STEP" "Настройка мониторинга контейнеров"
  
  if [ -f "${SYSTEM_DIR}/container-monitor.sh" ]; then
    log_message "INFO" "Запуск скрипта настройки мониторинга"
    ${SYSTEM_DIR}/container-monitor.sh --setup
    if [ $? -eq 0 ]; then
      log_message "INFO" "Мониторинг контейнеров успешно настроен"
    else
      log_message "ERROR" "Не удалось настроить мониторинг контейнеров"
      return 1
    fi
  else
    log_message "ERROR" "Скрипт мониторинга контейнеров не найден"
    return 1
  fi
  
  return 0
}

# Функция для настройки резервного копирования
setup_backup() {
  log_message "STEP" "Настройка резервного копирования"
  
  if [ -f "${BACKUP_DIR}/setup-backup-cron.sh" ]; then
    log_message "INFO" "Запуск скрипта настройки резервного копирования"
    ${BACKUP_DIR}/setup-backup-cron.sh
    if [ $? -eq 0 ]; then
      log_message "INFO" "Резервное копирование успешно настроено"
    else
      log_message "ERROR" "Не удалось настроить резервное копирование"
      return 1
    fi
  else
    log_message "ERROR" "Скрипт настройки резервного копирования не найден"
    return 1
  fi
  
  return 0
}

# Функция для оптимизации баз данных
setup_database_optimization() {
  log_message "STEP" "Оптимизация баз данных"
  
  # Оптимизация PostgreSQL
  if [ -f "${BACKUP_DIR}/postgres-optimization.sh" ]; then
    log_message "INFO" "Запуск скрипта оптимизации PostgreSQL"
    ${BACKUP_DIR}/postgres-optimization.sh
    if [ $? -eq 0 ]; then
      log_message "INFO" "PostgreSQL успешно оптимизирован"
    else
      log_message "WARN" "Не удалось оптимизировать PostgreSQL"
    fi
  else
    log_message "WARN" "Скрипт оптимизации PostgreSQL не найден"
  fi
  
  # Оптимизация MariaDB
  if [ -f "${BACKUP_DIR}/mariadb-optimization.sh" ]; then
    log_message "INFO" "Запуск скрипта оптимизации MariaDB"
    ${BACKUP_DIR}/mariadb-optimization.sh
    if [ $? -eq 0 ]; then
      log_message "INFO" "MariaDB успешно оптимизирован"
    else
      log_message "WARN" "Не удалось оптимизировать MariaDB"
    fi
  else
    log_message "WARN" "Скрипт оптимизации MariaDB не найден"
  fi
  
  return 0
}

# Функция для настройки автозапуска служб
setup_autostart() {
  log_message "STEP" "Настройка автозапуска служб мониторинга"
  
  # Создание systemd-сервиса для мониторинга контейнеров
  if [ -f "${SYSTEM_DIR}/container-monitor.sh" ]; then
    cat > "/tmp/container-monitor.service" << EOF
[Unit]
Description=Docker Container Health Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=${SYSTEM_DIR}/container-monitor.sh --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Копирование и активация сервиса
    mv "/tmp/container-monitor.service" "/etc/systemd/system/"
    systemctl daemon-reload
    systemctl enable container-monitor.service
    systemctl start container-monitor.service
    
    if [ $? -eq 0 ]; then
      log_message "INFO" "Служба мониторинга контейнеров успешно настроена на автозапуск"
    else
      log_message "ERROR" "Не удалось настроить автозапуск службы мониторинга контейнеров"
      return 1
    fi
  else
    log_message "ERROR" "Скрипт мониторинга контейнеров не найден"
    return 1
  fi
  
  return 0
}

# Функция для проверки успешности настройки
verify_setup() {
  log_message "STEP" "Проверка настройки компонентов отказоустойчивости"
  
  # Проверка прав на выполнение
  local all_scripts_executable=true
  find "${BACKUP_DIR}" -name "*.sh" -type f | while read -r script; do
    if [ ! -x "${script}" ]; then
      log_message "ERROR" "Скрипт ${script} не имеет прав на выполнение"
      all_scripts_executable=false
    fi
  done
  
  # Проверка копирования файлов
  local all_files_copied=true
  local files=(
    "docker-backup.sh"
    "docker-restore.sh"
    "container-monitor.sh"
    "system-diagnostics.sh"
    "system-recovery.sh"
  )
  
  for file in "${files[@]}"; do
    if [ ! -f "${SYSTEM_DIR}/${file}" ]; then
      log_message "ERROR" "Файл ${file} не найден в ${SYSTEM_DIR}"
      all_files_copied=false
    fi
  done
  
  # Проверка работы служб
  if ! systemctl is-active --quiet container-monitor.service; then
    log_message "ERROR" "Служба мониторинга контейнеров не запущена"
    return 1
  fi
  
  # Итоговый результат
  if [ "${all_scripts_executable}" = true ] && [ "${all_files_copied}" = true ]; then
    log_message "INFO" "Все компоненты отказоустойчивости успешно настроены"
    return 0
  else
    log_message "ERROR" "Настройка компонентов отказоустойчивости завершилась с ошибками"
    return 1
  fi
}

# Главная функция
main() {
  log_message "STEP" "Начало настройки системы отказоустойчивости"
  
  # Проверка наличия root-привилегий
  if [ "$(id -u)" -ne 0 ]; then
    log_message "ERROR" "Этот скрипт должен быть запущен с правами root (sudo)"
    exit 1
  fi
  
  # Установка прав на выполнение
  setup_permissions || exit 1
  
  # Копирование файлов
  copy_files_to_system || exit 1
  
  # Настройка мониторинга
  setup_container_monitoring || exit 1
  
  # Настройка резервного копирования
  setup_backup || exit 1
  
  # Оптимизация баз данных
  setup_database_optimization
  
  # Настройка автозапуска
  setup_autostart || exit 1
  
  # Проверка успешности настройки
  verify_setup
  
  log_message "STEP" "Настройка системы отказоустойчивости завершена"
  
  echo -e "\n${GREEN}Система отказоустойчивости успешно настроена!${NC}"
  echo -e "Доступные команды:"
  echo -e "  ${YELLOW}sudo ${SYSTEM_DIR}/system-diagnostics.sh --once${NC} - Запуск диагностики"
  echo -e "  ${YELLOW}sudo ${SYSTEM_DIR}/docker-backup.sh${NC} - Ручное создание резервной копии"
  echo -e "  ${YELLOW}sudo ${SYSTEM_DIR}/docker-restore.sh${NC} - Восстановление из резервной копии"
  echo -e "  ${YELLOW}sudo ${SYSTEM_DIR}/system-recovery.sh --auto${NC} - Автоматическое восстановление"
  echo -e "\nЛог установки сохранен в файле: ${LOG_FILE}"
  
  return 0
}

# Запуск главной функции
main
