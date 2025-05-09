#!/bin/bash

# =================================================================
# Скрипт восстановления системы после диагностики
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
LOG_FILE="/var/log/system-recovery.log"
DOCKER_COMPOSE_FILE="/opt/docker-compose.yaml"
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_STATE_FILE="/tmp/recovery_state.json"
DIAGNOSTICS_SCRIPT="/opt/system-diagnostics.sh"

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

# Функция для перезапуска контейнера
restart_container() {
  local container_name=$1
  
  log_message "INFO" "Перезапуск контейнера: ${container_name}"
  
  # Проверяем количество попыток перезапуска
  local attempts=0
  if [ -f "${RECOVERY_STATE_FILE}" ]; then
    attempts=$(jq -r ".\"${container_name}\".attempts // 0" "${RECOVERY_STATE_FILE}")
  else
    echo '{}' > "${RECOVERY_STATE_FILE}"
  fi
  
  # Увеличиваем счетчик попыток
  attempts=$((attempts + 1))
  jq --arg name "${container_name}" --argjson attempts "${attempts}" \
    '.[$name].attempts = $attempts' "${RECOVERY_STATE_FILE}" > "${RECOVERY_STATE_FILE}.tmp" && \
    mv "${RECOVERY_STATE_FILE}.tmp" "${RECOVERY_STATE_FILE}"
  
  # Если превышено максимальное количество попыток, пропускаем
  if [ "${attempts}" -gt "${MAX_RECOVERY_ATTEMPTS}" ]; then
    log_message "ERROR" "Превышено максимальное количество попыток перезапуска контейнера ${container_name}: ${attempts}/${MAX_RECOVERY_ATTEMPTS}"
    return 1
  fi
  
  log_message "INFO" "Попытка ${attempts}/${MAX_RECOVERY_ATTEMPTS} перезапуска контейнера ${container_name}"
  
  # Перезапускаем контейнер
  docker restart "${container_name}"
  local result=$?
  
  # Ожидаем запуска контейнера
  sleep 10
  
  # Проверяем статус контейнера после перезапуска
  local status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null || echo "unknown")
  
  if [ "${status}" = "running" ]; then
    log_message "INFO" "Контейнер ${container_name} успешно перезапущен"
    return 0
  else
    log_message "ERROR" "Не удалось перезапустить контейнер ${container_name}, статус: ${status}"
    return 1
  fi
}

# Функция для перезапуска базы данных с восстановлением
restart_database() {
  local container_name=$1
  local db_type=$2  # postgres или mysql
  
  log_message "INFO" "Перезапуск базы данных ${db_type} в контейнере ${container_name}"
  
  # Останавливаем контейнер
  docker stop "${container_name}"
  
  # Запускаем контейнер с опцией восстановления
  docker start "${container_name}"
  
  # Ожидаем запуска базы данных
  sleep 20
  
  # Проверяем состояние базы данных
  local status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null || echo "unknown")
  
  if [ "${status}" != "running" ]; then
    log_message "ERROR" "Не удалось запустить базу данных ${container_name}, статус: ${status}"
    return 1
  fi
  
  # Выполняем проверку базы данных
  if [ "${db_type}" = "postgres" ]; then
    docker exec "${container_name}" bash -c "postgres --single -D /var/lib/postgresql/data -c config_file=/var/lib/postgresql/data/postgresql.conf postgres < /dev/null > /dev/null"
    local result=$?
  elif [ "${db_type}" = "mysql" ]; then
    docker exec "${container_name}" bash -c "mysqlcheck --all-databases -u root -p\${MYSQL_ROOT_PASSWORD}"
    local result=$?
  else
    log_message "ERROR" "Неизвестный тип базы данных: ${db_type}"
    return 1
  fi
  
  if [ "${result}" -eq 0 ]; then
    log_message "INFO" "База данных ${container_name} успешно перезапущена и проверена"
    return 0
  else
    log_message "ERROR" "Проверка базы данных ${container_name} завершилась с ошибкой"
    return 1
  fi
}

# Функция для полного перезапуска стека
restart_stack() {
  log_message "INFO" "Полный перезапуск стека"
  
  # Проверяем существование docker-compose файла
  if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_message "ERROR" "Docker Compose файл не найден: ${DOCKER_COMPOSE_FILE}"
    return 1
  fi
  
  # Останавливаем все контейнеры
  log_message "INFO" "Останавливаем все контейнеры"
  docker compose -f "${DOCKER_COMPOSE_FILE}" down
  
  # Ожидаем полной остановки
  sleep 10
  
  # Запускаем все контейнеры
  log_message "INFO" "Запускаем все контейнеры"
  docker compose -f "${DOCKER_COMPOSE_FILE}" up -d
  
  # Ожидаем запуска контейнеров
  sleep 30
  
  # Проверяем, все ли контейнеры запущены
  local containers=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q)
  local all_running=true
  
  for container in ${containers}; do
    local container_name=$(docker inspect --format='{{.Name}}' "${container}" | sed 's/^\///')
    local status=$(docker inspect --format='{{.State.Status}}' "${container_name}")
    
    if [ "${status}" != "running" ]; then
      log_message "ERROR" "Контейнер ${container_name} не запущен после перезапуска стека (статус: ${status})"
      all_running=false
    fi
  done
  
  if [ "${all_running}" = true ]; then
    log_message "INFO" "Все контейнеры успешно запущены после перезапуска стека"
    return 0
  else
    log_message "ERROR" "Некоторые контейнеры не запущены после перезапуска стека"
    return 1
  fi
}

# Функция для очистки неиспользуемых ресурсов Docker
cleanup_docker_resources() {
  log_message "INFO" "Очистка неиспользуемых ресурсов Docker"
  
  # Удаление остановленных контейнеров
  log_message "INFO" "Удаление остановленных контейнеров"
  docker container prune -f
  
  # Удаление неиспользуемых образов
  log_message "INFO" "Удаление неиспользуемых образов"
  docker image prune -f
  
  # Удаление неиспользуемых томов
  log_message "INFO" "Удаление неиспользуемых томов"
  docker volume prune -f
  
  # Удаление неиспользуемых сетей
  log_message "INFO" "Удаление неиспользуемых сетей"
  docker network prune -f
  
  log_message "INFO" "Очистка неиспользуемых ресурсов Docker завершена"
  return 0
}

# Функция для восстановления из резервной копии
restore_from_backup() {
  local backup_type=$1  # full, postgres, mysql, n8n и т.д.
  local backup_id=$2    # Идентификатор резервной копии (дата/время)
  
  log_message "INFO" "Восстановление из резервной копии: тип=${backup_type}, ID=${backup_id}"
  
  case "${backup_type}" in
    "full")
      # Вызываем скрипт полного восстановления
      /home/den/my-nocode-stack/backup/docker-restore.sh --yes "${backup_id}"
      local result=$?
      ;;
    "postgres")
      # Вызываем скрипт восстановления только для PostgreSQL
      /home/den/my-nocode-stack/backup/docker-restore.sh --yes --volumes n8n_postgres_data "${backup_id}"
      local result=$?
      ;;
    "mysql")
      # Вызываем скрипт восстановления только для MySQL/MariaDB
      /home/den/my-nocode-stack/backup/docker-restore.sh --yes --volumes wordpress_db_data "${backup_id}"
      local result=$?
      ;;
    "n8n")
      # Вызываем скрипт восстановления только для n8n
      /home/den/my-nocode-stack/backup/docker-restore.sh --yes --volumes n8n_data "${backup_id}"
      local result=$?
      ;;
    *)
      log_message "ERROR" "Неизвестный тип резервной копии: ${backup_type}"
      return 1
      ;;
  esac
  
  if [ "${result}" -eq 0 ]; then
    log_message "INFO" "Восстановление из резервной копии успешно завершено"
    return 0
  else
    log_message "ERROR" "Восстановление из резервной копии завершилось с ошибкой"
    return 1
  fi
}

# Функция для поиска последней успешной резервной копии
find_latest_backup() {
  local backup_root="/opt/backups"
  
  log_message "INFO" "Поиск последней успешной резервной копии в ${backup_root}"
  
  # Ищем директории резервных копий
  local latest_backup=$(find "${backup_root}" -maxdepth 1 -type d -name "????-??-??_??-??-??" | sort -r | head -1)
  
  if [ -z "${latest_backup}" ]; then
    log_message "ERROR" "Резервные копии не найдены в ${backup_root}"
    return 1
  fi
  
  # Проверяем наличие метаданных в резервной копии
  if [ ! -f "${latest_backup}/metadata.json" ]; then
    log_message "ERROR" "Последняя резервная копия повреждена: отсутствует файл метаданных"
    return 1
  fi
  
  # Выводим идентификатор последней резервной копии
  local backup_id=$(basename "${latest_backup}")
  echo "${backup_id}"
  
  log_message "INFO" "Найдена последняя резервная копия: ${backup_id}"
  return 0
}

# Функция для автоматического восстановления системы
auto_recovery() {
  log_message "INFO" "Запуск автоматического восстановления системы"
  
  # Запускаем диагностику системы
  "${DIAGNOSTICS_SCRIPT}" --once > /tmp/diagnostics_output.txt
  local diagnostics_result=$?
  
  # Анализируем результаты диагностики
  if [ "${diagnostics_result}" -eq 0 ]; then
    log_message "INFO" "Диагностика не выявила проблем. Восстановление не требуется."
    return 0
  fi
  
  # Проверяем наличие проблем с базами данных
  if grep -q "Error.*postgres" /tmp/diagnostics_output.txt; then
    log_message "WARN" "Обнаружены проблемы с PostgreSQL. Попытка перезапуска."
    restart_database "postgres" "postgres"
    
    # Если перезапуск не помог, восстанавливаем из резервной копии
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось восстановить PostgreSQL перезапуском. Попытка восстановления из резервной копии."
      local latest_backup=$(find_latest_backup)
      
      if [ -n "${latest_backup}" ]; then
        restore_from_backup "postgres" "${latest_backup}"
      fi
    fi
  fi
  
  if grep -q "Error.*mariadb\|mysql\|wordpress_db" /tmp/diagnostics_output.txt; then
    log_message "WARN" "Обнаружены проблемы с MariaDB. Попытка перезапуска."
    restart_database "wordpress_db" "mysql"
    
    # Если перезапуск не помог, восстанавливаем из резервной копии
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Не удалось восстановить MariaDB перезапуском. Попытка восстановления из резервной копии."
      local latest_backup=$(find_latest_backup)
      
      if [ -n "${latest_backup}" ]; then
        restore_from_backup "mysql" "${latest_backup}"
      fi
    fi
  fi
  
  # Проверяем наличие проблем с отдельными контейнерами
  grep -o "Error.*контейнер [^ ]* " /tmp/diagnostics_output.txt | sed 's/Error.*контейнер \([^ ]*\) .*/\1/' | while read -r container; do
    log_message "WARN" "Обнаружены проблемы с контейнером ${container}. Попытка перезапуска."
    restart_container "${container}"
  done
  
  # Проверяем, решены ли проблемы
  "${DIAGNOSTICS_SCRIPT}" --once > /tmp/diagnostics_output_after.txt
  local after_result=$?
  
  if [ "${after_result}" -eq 0 ]; then
    log_message "INFO" "Восстановление системы успешно завершено."
    return 0
  else
    # Если все частичные восстановления не помогли, делаем полный перезапуск стека
    log_message "WARN" "Частичное восстановление не помогло. Попытка полного перезапуска стека."
    restart_stack
    
    # Если и это не помогло, пытаемся восстановиться из резервной копии
    if [ $? -ne 0 ]; then
      log_message "ERROR" "Полный перезапуск стека не помог. Попытка восстановления из последней резервной копии."
      local latest_backup=$(find_latest_backup)
      
      if [ -n "${latest_backup}" ]; then
        restore_from_backup "full" "${latest_backup}"
      fi
    fi
    
    # Финальная проверка
    "${DIAGNOSTICS_SCRIPT}" --once > /tmp/diagnostics_output_final.txt
    local final_result=$?
    
    if [ "${final_result}" -eq 0 ]; then
      log_message "INFO" "Восстановление системы успешно завершено после полного перезапуска."
      return 0
    else
      log_message "ERROR" "Не удалось восстановить систему. Требуется ручное вмешательство."
      return 1
    fi
  fi
}

# Основная функция
main() {
  # Проверяем аргументы командной строки
  local mode="interactive"
  local action=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --auto)
        mode="auto"
        shift
        ;;
      --restart-container)
        action="restart_container"
        container_name="$2"
        shift 2
        ;;
      --restart-db)
        action="restart_database"
        db_container="$2"
        db_type="$3"
        shift 3
        ;;
      --restart-stack)
        action="restart_stack"
        shift
        ;;
      --cleanup)
        action="cleanup_docker_resources"
        shift
        ;;
      --restore)
        action="restore_from_backup"
        backup_type="$2"
        backup_id="$3"
        shift 3
        ;;
      *)
        echo "Использование: $0 [--auto] [--restart-container CONTAINER] [--restart-db CONTAINER TYPE] [--restart-stack] [--cleanup] [--restore TYPE ID]"
        exit 1
        ;;
    esac
  done
  
  # Выполняем действие в соответствии с режимом
  if [ "${mode}" = "auto" ]; then
    auto_recovery
    exit $?
  elif [ -n "${action}" ]; then
    case "${action}" in
      restart_container)
        restart_container "${container_name}"
        exit $?
        ;;
      restart_database)
        restart_database "${db_container}" "${db_type}"
        exit $?
        ;;
      restart_stack)
        restart_stack
        exit $?
        ;;
      cleanup_docker_resources)
        cleanup_docker_resources
        exit $?
        ;;
      restore_from_backup)
        restore_from_backup "${backup_type}" "${backup_id}"
        exit $?
        ;;
    esac
  else
    # Интерактивный режим
    echo -e "${GREEN}=== Система восстановления стека сервисов ===${NC}"
    echo "1) Автоматическое восстановление системы"
    echo "2) Перезапуск отдельного контейнера"
    echo "3) Перезапуск базы данных"
    echo "4) Полный перезапуск стека"
    echo "5) Очистка неиспользуемых ресурсов Docker"
    echo "6) Восстановление из резервной копии"
    
    read -p "Выберите действие [1-6]: " choice
    
    case $choice in
      1)
        auto_recovery
        ;;
      2)
        echo "Доступные контейнеры:"
        docker ps --format "{{.Names}}"
        read -p "Введите имя контейнера: " container_name
        restart_container "${container_name}"
        ;;
      3)
        echo "1) PostgreSQL (postgres)"
        echo "2) MariaDB (wordpress_db)"
        read -p "Выберите базу данных [1-2]: " db_choice
        
        case $db_choice in
          1)
            restart_database "postgres" "postgres"
            ;;
          2)
            restart_database "wordpress_db" "mysql"
            ;;
          *)
            echo "Неверный выбор"
            exit 1
            ;;
        esac
        ;;
      4)
        read -p "Вы уверены, что хотите перезапустить весь стек? [y/N] " confirm
        if [[ "${confirm}" =~ ^[Yy]$ ]]; then
          restart_stack
        fi
        ;;
      5)
        read -p "Вы уверены, что хотите очистить неиспользуемые ресурсы Docker? [y/N] " confirm
        if [[ "${confirm}" =~ ^[Yy]$ ]]; then
          cleanup_docker_resources
        fi
        ;;
      6)
        echo "Типы резервных копий:"
        echo "1) Полная резервная копия (full)"
        echo "2) Только PostgreSQL (postgres)"
        echo "3) Только MariaDB (mysql)"
        echo "4) Только n8n (n8n)"
        
        read -p "Выберите тип резервной копии [1-4]: " backup_choice
        
        case $backup_choice in
          1) backup_type="full" ;;
          2) backup_type="postgres" ;;
          3) backup_type="mysql" ;;
          4) backup_type="n8n" ;;
          *) 
            echo "Неверный выбор"
            exit 1
            ;;
        esac
        
        # Находим последнюю резервную копию
        latest_backup=$(find_latest_backup)
        
        if [ -n "${latest_backup}" ]; then
          read -p "Использовать последнюю резервную копию (${latest_backup})? [Y/n] " use_latest
          
          if [[ ! "${use_latest}" =~ ^[Nn]$ ]]; then
            backup_id="${latest_backup}"
          else
            read -p "Введите ID резервной копии (формат: YYYY-MM-DD_HH-MM-SS): " backup_id
          fi
          
          restore_from_backup "${backup_type}" "${backup_id}"
        else
          echo "Резервные копии не найдены"
          exit 1
        fi
        ;;
      *)
        echo "Неверный выбор"
        exit 1
        ;;
    esac
  fi
}

# Запуск основной функции
main "$@"
