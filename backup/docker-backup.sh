#!/bin/bash

# =================================================================
# Скрипт автоматического резервного копирования Docker-томов
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки резервного копирования
BACKUP_ROOT="/opt/backups"
DATE_FORMAT=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="${BACKUP_ROOT}/${DATE_FORMAT}"
LOG_FILE="${BACKUP_ROOT}/backup.log"
RETENTION_DAYS=7
MAX_BACKUP_SIZE_GB=100
COMPRESS=true
VERIFY=true

# Список томов Docker для резервного копирования
DOCKER_VOLUMES=(
  "n8n_data"
  "n8n_redis_data"
  "n8n_postgres_data"
  "caddy_data"
  "caddy_config"
  "flowise_data"
  "qdrant_storage"
  "wordpress_data"
  "wordpress_db_data"
  "waha_sessions"
  "waha_media"
  "netdataconfig"
  "netdatalib"
  "netdatacache"
)

# Функция для логирования сообщений
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

# Функция проверки доступного места на диске
check_disk_space() {
  local required_space=$1  # в ГБ
  local disk_path=$2
  
  # Получаем доступное место в ГБ
  local available_space=$(df -BG "${disk_path}" | awk 'NR==2 {gsub("G", "", $4); print $4}')
  
  if (( available_space < required_space )); then
    log_message "ERROR" "Недостаточно места на диске: ${available_space}GB доступно, необходимо ${required_space}GB"
    return 1
  else
    log_message "INFO" "Проверка места на диске успешна: ${available_space}GB доступно"
    return 0
  fi
}

# Функция для проверки успешности выполнения команды
check_command() {
  if [ $? -ne 0 ]; then
    log_message "ERROR" "Ошибка при выполнении команды: $1"
    return 1
  fi
  return 0
}

# Функция для резервного копирования одного Docker-тома
backup_volume() {
  local volume=$1
  local backup_path="${BACKUP_DIR}/volumes/${volume}"
  
  log_message "INFO" "Начало резервного копирования тома: ${volume}"
  
  # Создание директории для резервной копии
  mkdir -p "${backup_path}"
  check_command "Не удалось создать директорию ${backup_path}" || return 1
  
  # Проверяем существование тома
  if ! docker volume inspect "${volume}" &>/dev/null; then
    log_message "WARN" "Том ${volume} не существует, пропускаем"
    return 0
  fi
  
  # Получение данных тома с помощью временного контейнера
  docker run --rm -v "${volume}:/source" -v "${backup_path}:/backup" alpine sh -c "cd /source && tar cf - . | tar xf - -C /backup"
  
  if check_command "Ошибка копирования данных тома ${volume}"; then
    # Если компрессия включена, сжимаем резервную копию
    if [ "${COMPRESS}" = true ]; then
      log_message "INFO" "Сжатие резервной копии тома: ${volume}"
      tar -czf "${backup_path}.tar.gz" -C "${backup_path}" .
      check_command "Ошибка сжатия резервной копии тома ${volume}" || return 1
      
      # Удаляем несжатую директорию после успешной компрессии
      rm -rf "${backup_path}"
      check_command "Ошибка удаления временной директории ${backup_path}" || log_message "WARN" "Не удалось удалить временную директорию ${backup_path}"
    fi
    
    log_message "INFO" "Резервное копирование тома ${volume} успешно завершено"
    return 0
  else
    log_message "ERROR" "Не удалось создать резервную копию тома ${volume}"
    return 1
  fi
}

# Функция для резервного копирования файлов конфигурации
backup_config_files() {
  local config_backup="${BACKUP_DIR}/configs"
  
  log_message "INFO" "Начало резервного копирования файлов конфигурации"
  
  # Создание директории для резервных копий конфигурации
  mkdir -p "${config_backup}"
  check_command "Не удалось создать директорию ${config_backup}" || return 1
  
  # Список важных конфигурационных файлов и директорий
  local config_paths=(
    "/opt/docker-compose.yaml"
    "/opt/.env"
    "/opt/Caddyfile"
    "/home/den/my-nocode-stack"
  )
  
  # Копирование каждого файла/директории
  for path in "${config_paths[@]}"; do
    if [ -e "${path}" ]; then
      log_message "INFO" "Копирование: ${path}"
      
      # Получение имени файла/директории
      local name=$(basename "${path}")
      
      if [ -d "${path}" ]; then
        # Если это директория, создаем tar-архив
        tar -czf "${config_backup}/${name}.tar.gz" -C "$(dirname "${path}")" "${name}"
      else
        # Если это файл, просто копируем
        cp "${path}" "${config_backup}/"
      fi
      
      check_command "Ошибка копирования ${path}" || log_message "WARN" "Не удалось скопировать ${path}"
    else
      log_message "WARN" "Путь не существует, пропускаем: ${path}"
    fi
  done
  
  log_message "INFO" "Резервное копирование файлов конфигурации завершено"
  return 0
}

# Функция для создания метаданных резервной копии
create_backup_metadata() {
  local metadata_file="${BACKUP_DIR}/metadata.json"
  
  log_message "INFO" "Создание метаданных резервной копии"
  
  # Получение информации о системе
  local hostname=$(hostname)
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local docker_version=$(docker --version)
  local disk_usage=$(du -sh "${BACKUP_DIR}" | cut -f1)
  
  # Создание JSON с метаданными
  cat > "${metadata_file}" << EOF
{
  "backup_id": "${DATE_FORMAT}",
  "created_at": "${timestamp}",
  "hostname": "${hostname}",
  "docker_version": "${docker_version}",
  "volumes_included": [$(printf '"%s",' "${DOCKER_VOLUMES[@]}" | sed 's/,$//')],
  "disk_usage": "${disk_usage}",
  "compressed": ${COMPRESS},
  "verified": ${VERIFY}
}
EOF
  
  check_command "Не удалось создать файл метаданных" || return 1
  log_message "INFO" "Метаданные созданы успешно: ${metadata_file}"
  return 0
}

# Функция для проверки резервной копии
verify_backup() {
  local backup_dir=$1
  
  log_message "INFO" "Начало проверки резервной копии: ${backup_dir}"
  
  # Проверка наличия всех ожидаемых файлов
  local expected_files=("metadata.json")
  
  if [ "${COMPRESS}" = true ]; then
    # Если используется сжатие, проверяем наличие сжатых томов
    for volume in "${DOCKER_VOLUMES[@]}"; do
      expected_files+=("volumes/${volume}.tar.gz")
    done
  else
    # Иначе проверяем наличие директорий томов
    for volume in "${DOCKER_VOLUMES[@]}"; do
      expected_files+=("volumes/${volume}")
    done
  fi
  
  local all_present=true
  
  for file in "${expected_files[@]}"; do
    if [ ! -e "${backup_dir}/${file}" ]; then
      log_message "ERROR" "Отсутствует ожидаемый файл/директория: ${file}"
      all_present=false
    fi
  done
  
  if [ "${all_present}" = true ]; then
    log_message "INFO" "Проверка резервной копии успешна: все ожидаемые файлы присутствуют"
    return 0
  else
    log_message "ERROR" "Проверка резервной копии не удалась: некоторые файлы отсутствуют"
    return 1
  fi
}

# Функция для удаления старых резервных копий
cleanup_old_backups() {
  log_message "INFO" "Начало очистки старых резервных копий (старше ${RETENTION_DAYS} дней)"
  
  # Находим и удаляем директории резервных копий старше RETENTION_DAYS дней
  find "${BACKUP_ROOT}" -maxdepth 1 -type d -name "????-??-??_??-??-??" -mtime +${RETENTION_DAYS} | while read -r old_backup; do
    log_message "INFO" "Удаление старой резервной копии: ${old_backup}"
    rm -rf "${old_backup}"
    check_command "Не удалось удалить старую резервную копию: ${old_backup}" || log_message "WARN" "Ошибка при удалении ${old_backup}"
  done
  
  log_message "INFO" "Очистка старых резервных копий завершена"
  return 0
}

# Основная функция создания резервной копии
perform_backup() {
  log_message "INFO" "=== Начало процесса резервного копирования ==="
  
  # Проверка наличия root привилегий
  if [ "$(id -u)" -ne 0 ]; then
    log_message "ERROR" "Этот скрипт должен быть запущен с привилегиями root"
    return 1
  fi
  
  # Проверка существования корневой директории для резервных копий
  mkdir -p "${BACKUP_ROOT}"
  check_command "Не удалось создать корневую директорию для резервных копий: ${BACKUP_ROOT}" || return 1
  
  # Проверка доступного места на диске
  check_disk_space "${MAX_BACKUP_SIZE_GB}" "${BACKUP_ROOT}" || return 1
  
  # Создание директории для текущей резервной копии
  mkdir -p "${BACKUP_DIR}/volumes"
  check_command "Не удалось создать директорию для текущей резервной копии: ${BACKUP_DIR}" || return 1
  
  # Резервное копирование Docker-томов
  local backup_failed=false
  
  for volume in "${DOCKER_VOLUMES[@]}"; do
    backup_volume "${volume}" || backup_failed=true
  done
  
  # Резервное копирование файлов конфигурации
  backup_config_files || backup_failed=true
  
  # Создание метаданных резервной копии
  create_backup_metadata || backup_failed=true
  
  # Проверка резервной копии
  if [ "${VERIFY}" = true ]; then
    verify_backup "${BACKUP_DIR}" || backup_failed=true
  fi
  
  # Очистка старых резервных копий
  cleanup_old_backups
  
  # Итоговый результат
  if [ "${backup_failed}" = true ]; then
    log_message "ERROR" "=== Процесс резервного копирования завершен с ошибками ==="
    return 1
  else
    log_message "INFO" "=== Процесс резервного копирования успешно завершен ==="
    log_message "INFO" "Резервная копия сохранена в: ${BACKUP_DIR}"
    log_message "INFO" "Размер резервной копии: $(du -sh "${BACKUP_DIR}" | cut -f1)"
    return 0
  fi
}

# Запуск процесса резервного копирования
perform_backup
exit $?
