#!/bin/bash

# =================================================================
# Скрипт восстановления из резервной копии Docker-томов
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки по умолчанию
BACKUP_ROOT="/opt/backups"
LOG_FILE="/var/log/docker-restore.log"
VERIFY_BEFORE_RESTORE=true
ASK_CONFIRMATION=true

# Функция для вывода справки
show_help() {
  echo -e "${GREEN}=== Скрипт восстановления из резервной копии Docker-томов ===${NC}"
  echo -e "Использование: $0 [ОПЦИИ] BACKUP_ID"
  echo -e "  BACKUP_ID - идентификатор резервной копии в формате YYYY-MM-DD_HH-MM-SS"
  echo -e "\nОпции:"
  echo -e "  -h, --help             Показать эту справку"
  echo -e "  -b, --backup-dir DIR   Указать корневую директорию резервных копий (по умолчанию: ${BACKUP_ROOT})"
  echo -e "  -y, --yes              Не запрашивать подтверждение перед восстановлением"
  echo -e "  -s, --skip-verify      Пропустить проверку резервной копии перед восстановлением"
  echo -e "  -v, --volumes VOL1,VOL2 Восстановить только указанные тома (через запятую, без пробелов)"
  echo -e "\nПримеры использования:"
  echo -e "  $0 2025-05-08_10-15-30          # Восстановить из указанной резервной копии"
  echo -e "  $0 -y 2025-05-08_10-15-30       # Восстановить без запроса подтверждения"
  echo -e "  $0 -v n8n_data,qdrant_storage 2025-05-08_10-15-30  # Восстановить только указанные тома"
  exit 0
}

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

# Функция для проверки успешности выполнения команды
check_command() {
  if [ $? -ne 0 ]; then
    log_message "ERROR" "Ошибка при выполнении команды: $1"
    return 1
  fi
  return 0
}

# Функция для проверки резервной копии
verify_backup() {
  local backup_dir=$1
  
  log_message "INFO" "Проверка резервной копии: ${backup_dir}"
  
  # Проверка существования директории резервной копии
  if [ ! -d "${backup_dir}" ]; then
    log_message "ERROR" "Директория резервной копии не существует: ${backup_dir}"
    return 1
  fi
  
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
  
  # Чтение информации о сжатии из метаданных
  local compressed=$(grep -o '"compressed": *[^,}]*' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d ' ')
  
  # Получение списка томов из метаданных
  local volumes_json=$(grep -o '"volumes_included": *\[[^]]*\]' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d '[]" ')
  local volumes=($(echo ${volumes_json} | tr ',' ' '))
  
  # Проверка наличия файлов/директорий томов
  local all_present=true
  
  for volume in "${volumes[@]}"; do
    if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
      # Проверяем наличие сжатого архива тома
      if [ ! -f "${backup_dir}/volumes/${volume}.tar.gz" ]; then
        log_message "ERROR" "Архив тома отсутствует: ${backup_dir}/volumes/${volume}.tar.gz"
        all_present=false
      fi
    else
      # Проверяем наличие директории тома
      if [ ! -d "${backup_dir}/volumes/${volume}" ]; then
        log_message "ERROR" "Директория тома отсутствует: ${backup_dir}/volumes/${volume}"
        all_present=false
      fi
    fi
  done
  
  if [ "${all_present}" = "true" ]; then
    log_message "INFO" "Проверка резервной копии успешна: все необходимые файлы присутствуют"
    return 0
  else
    log_message "ERROR" "Проверка резервной копии не удалась: некоторые файлы отсутствуют"
    return 1
  fi
}

# Функция для восстановления одного Docker-тома
restore_volume() {
  local volume=$1
  local backup_dir=$2
  local compressed=$3
  
  log_message "INFO" "Начало восстановления тома: ${volume}"
  
  # Проверяем существование тома
  if ! docker volume inspect "${volume}" &>/dev/null; then
    log_message "WARN" "Том ${volume} не существует, создаем новый"
    docker volume create "${volume}"
    check_command "Не удалось создать том ${volume}" || return 1
  fi
  
  # Создаем временную директорию для распаковки
  local temp_dir=$(mktemp -d)
  check_command "Не удалось создать временную директорию" || return 1
  
  # Восстанавливаем данные тома
  if [ "${compressed}" = "true" -o "${compressed}" = "True" ]; then
    # Распаковываем архив во временную директорию
    log_message "INFO" "Распаковка архива тома ${volume}"
    tar -xzf "${backup_dir}/volumes/${volume}.tar.gz" -C "${temp_dir}"
    check_command "Не удалось распаковать архив тома ${volume}" || return 1
  else
    # Копируем данные из резервной копии во временную директорию
    log_message "INFO" "Копирование данных тома ${volume}"
    cp -a "${backup_dir}/volumes/${volume}/." "${temp_dir}/"
    check_command "Не удалось скопировать данные тома ${volume}" || return 1
  fi
  
  # Копируем данные из временной директории в том с помощью временного контейнера
  log_message "INFO" "Запись данных в том ${volume}"
  docker run --rm -v "${volume}:/target" -v "${temp_dir}:/source" alpine sh -c "rm -rf /target/* && cp -a /source/. /target/"
  check_command "Не удалось записать данные в том ${volume}" || return 1
  
  # Удаляем временную директорию
  rm -rf "${temp_dir}"
  check_command "Не удалось удалить временную директорию" || log_message "WARN" "Не удалось удалить временную директорию: ${temp_dir}"
  
  log_message "INFO" "Восстановление тома ${volume} успешно завершено"
  return 0
}

# Функция для восстановления файлов конфигурации
restore_config_files() {
  local backup_dir=$1
  
  log_message "INFO" "Начало восстановления файлов конфигурации"
  
  # Проверка наличия директории с конфигурационными файлами
  if [ ! -d "${backup_dir}/configs" ]; then
    log_message "WARN" "Директория с конфигурационными файлами отсутствует: ${backup_dir}/configs"
    return 0
  fi
  
  # Список файлов конфигурации для восстановления
  local config_files=(
    "docker-compose.yaml"
    ".env"
    "Caddyfile"
  )
  
  # Восстановление каждого файла
  for file in "${config_files[@]}"; do
    if [ -f "${backup_dir}/configs/${file}" ]; then
      log_message "INFO" "Восстановление файла: ${file}"
      
      # Создание резервной копии текущего файла, если он существует
      if [ -f "/opt/${file}" ]; then
        local backup_timestamp=$(date +%Y%m%d%H%M%S)
        cp "/opt/${file}" "/opt/${file}.bak-${backup_timestamp}"
        check_command "Не удалось создать резервную копию файла /opt/${file}" || log_message "WARN" "Не удалось создать резервную копию файла /opt/${file}"
      fi
      
      # Копирование файла из резервной копии
      cp "${backup_dir}/configs/${file}" "/opt/${file}"
      check_command "Не удалось восстановить файл ${file}" || log_message "ERROR" "Не удалось восстановить файл ${file}"
    fi
  done
  
  # Проверка наличия архива с директорией my-nocode-stack
  if [ -f "${backup_dir}/configs/my-nocode-stack.tar.gz" ]; then
    log_message "INFO" "Восстановление директории my-nocode-stack"
    
    # Создание резервной копии текущей директории, если она существует
    if [ -d "/home/den/my-nocode-stack" ]; then
      local backup_timestamp=$(date +%Y%m%d%H%M%S)
      cp -r "/home/den/my-nocode-stack" "/home/den/my-nocode-stack.bak-${backup_timestamp}"
      check_command "Не удалось создать резервную копию директории my-nocode-stack" || log_message "WARN" "Не удалось создать резервную копию директории my-nocode-stack"
    fi
    
    # Распаковка архива
    tar -xzf "${backup_dir}/configs/my-nocode-stack.tar.gz" -C "/home/den/"
    check_command "Не удалось восстановить директорию my-nocode-stack" || log_message "ERROR" "Не удалось восстановить директорию my-nocode-stack"
  fi
  
  log_message "INFO" "Восстановление файлов конфигурации завершено"
  return 0
}

# Функция для перезапуска сервисов
restart_services() {
  log_message "INFO" "Перезапуск сервисов"
  
  # Остановка всех контейнеров
  log_message "INFO" "Остановка контейнеров"
  docker compose -f /opt/docker-compose.yaml down
  check_command "Не удалось остановить контейнеры" || log_message "WARN" "Не удалось остановить некоторые контейнеры"
  
  # Запуск контейнеров
  log_message "INFO" "Запуск контейнеров"
  docker compose -f /opt/docker-compose.yaml up -d
  check_command "Не удалось запустить контейнеры" || log_message "ERROR" "Не удалось запустить контейнеры"
  
  log_message "INFO" "Перезапуск сервисов завершен"
  return 0
}

# Основная функция восстановления
perform_restore() {
  local backup_id=$1
  local specific_volumes=("${@:2}")
  
  log_message "INFO" "=== Начало процесса восстановления ==="
  log_message "INFO" "Идентификатор резервной копии: ${backup_id}"
  
  # Проверка наличия root привилегий
  if [ "$(id -u)" -ne 0 ]; then
    log_message "ERROR" "Этот скрипт должен быть запущен с привилегиями root"
    return 1
  fi
  
  # Формирование пути к резервной копии
  local backup_dir="${BACKUP_ROOT}/${backup_id}"
  
  # Проверка резервной копии перед восстановлением
  if [ "${VERIFY_BEFORE_RESTORE}" = true ]; then
    log_message "INFO" "Проверка резервной копии перед восстановлением"
    
    if ! verify_backup "${backup_dir}"; then
      log_message "ERROR" "Проверка резервной копии не удалась, восстановление прервано"
      return 1
    fi
    
    log_message "INFO" "Проверка резервной копии успешно пройдена"
  fi
  
  # Чтение информации о сжатии из метаданных
  local compressed=$(grep -o '"compressed": *[^,}]*' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d ' ')
  
  # Получение списка томов из метаданных
  local volumes_json=$(grep -o '"volumes_included": *\[[^]]*\]' "${backup_dir}/metadata.json" | cut -d: -f2 | tr -d '[]" ')
  local volumes=($(echo ${volumes_json} | tr ',' ' '))
  
  # Фильтрация томов, если указаны конкретные тома для восстановления
  if [ ${#specific_volumes[@]} -gt 0 ]; then
    log_message "INFO" "Восстановление только указанных томов: ${specific_volumes[*]}"
    
    # Временный массив для хранения пересечения томов
    local filtered_volumes=()
    
    for vol in "${volumes[@]}"; do
      if [[ " ${specific_volumes[@]} " =~ " ${vol} " ]]; then
        filtered_volumes+=("${vol}")
      fi
    done
    
    # Проверка, что все указанные тома существуют в резервной копии
    for vol in "${specific_volumes[@]}"; do
      if [[ ! " ${volumes[@]} " =~ " ${vol} " ]]; then
        log_message "WARN" "Том ${vol} не найден в резервной копии и будет пропущен"
      fi
    done
    
    volumes=("${filtered_volumes[@]}")
  fi
  
  # Запрос подтверждения перед восстановлением
  if [ "${ASK_CONFIRMATION}" = true ]; then
    echo -e "${YELLOW}ВНИМАНИЕ: Вы собираетесь восстановить следующие тома:${NC}"
    for vol in "${volumes[@]}"; do
      echo "  - ${vol}"
    done
    echo -e "${YELLOW}Это действие перезапишет текущие данные. Продолжить? [y/N]${NC}"
    
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log_message "INFO" "Восстановление отменено пользователем"
      return 0
    fi
  fi
  
  # Остановка контейнеров перед восстановлением
  log_message "INFO" "Остановка контейнеров перед восстановлением"
  docker compose -f /opt/docker-compose.yaml down
  check_command "Не удалось остановить контейнеры" || log_message "WARN" "Не удалось остановить некоторые контейнеры"
  
  # Восстановление томов
  local restore_failed=false
  
  for volume in "${volumes[@]}"; do
    restore_volume "${volume}" "${backup_dir}" "${compressed}" || restore_failed=true
  done
  
  # Восстановление файлов конфигурации
  restore_config_files "${backup_dir}" || restore_failed=true
  
  # Перезапуск сервисов после восстановления
  restart_services || restore_failed=true
  
  # Итоговый результат
  if [ "${restore_failed}" = true ]; then
    log_message "ERROR" "=== Процесс восстановления завершен с ошибками ==="
    return 1
  else
    log_message "INFO" "=== Процесс восстановления успешно завершен ==="
    log_message "INFO" "Восстановление из резервной копии: ${backup_dir}"
    return 0
  fi
}

# Обработка аргументов командной строки
SPECIFIC_VOLUMES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -b|--backup-dir)
      BACKUP_ROOT="$2"
      shift 2
      ;;
    -y|--yes)
      ASK_CONFIRMATION=false
      shift
      ;;
    -s|--skip-verify)
      VERIFY_BEFORE_RESTORE=false
      shift
      ;;
    -v|--volumes)
      IFS=',' read -ra SPECIFIC_VOLUMES <<< "$2"
      shift 2
      ;;
    *)
      # Предполагаем, что последний аргумент - это ID резервной копии
      BACKUP_ID="$1"
      shift
      ;;
  esac
done

# Проверка наличия идентификатора резервной копии
if [ -z "${BACKUP_ID}" ]; then
  echo -e "${RED}Ошибка: Не указан идентификатор резервной копии${NC}"
  show_help
fi

# Вывод информации о восстановлении
echo -e "${GREEN}=== Скрипт восстановления из резервной копии Docker-томов ===${NC}"
echo -e "Идентификатор резервной копии: ${BACKUP_ID}"
echo -e "Корневая директория резервных копий: ${BACKUP_ROOT}"

if [ ${#SPECIFIC_VOLUMES[@]} -gt 0 ]; then
  echo -e "Восстановление только томов: ${SPECIFIC_VOLUMES[*]}"
fi

# Запуск процесса восстановления
perform_restore "${BACKUP_ID}" "${SPECIFIC_VOLUMES[@]}"
exit $?
