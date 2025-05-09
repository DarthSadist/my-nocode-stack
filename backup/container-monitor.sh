#!/bin/bash

# =================================================================
# Скрипт мониторинга состояния Docker-контейнеров
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
LOG_FILE="/var/log/container-monitor.log"
NOTIFICATION_EMAIL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=300  # 5 минут между попытками перезапуска
CHECK_INTERVAL=60     # Проверка каждую минуту
DOCKER_COMPOSE_FILE="/opt/docker-compose.yaml"

# Временный файл для хранения состояния
STATE_FILE="/tmp/container_monitor_state.json"

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

# Функция для отправки уведомлений
send_notification() {
  local subject=$1
  local message=$2
  
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

# Функция для проверки и обновления состояния контейнера
update_container_state() {
  local container_name=$1
  local current_status=$2
  local health_status=$3
  
  # Создаем файл состояния, если он не существует
  if [ ! -f "${STATE_FILE}" ]; then
    echo "{}" > "${STATE_FILE}"
  fi
  
  # Получаем текущее состояние
  local previous_status=$(jq -r ".[\"${container_name}\"].status // \"unknown\"" "${STATE_FILE}")
  local previous_health=$(jq -r ".[\"${container_name}\"].health // \"unknown\"" "${STATE_FILE}")
  local restart_count=$(jq -r ".[\"${container_name}\"].restart_count // 0" "${STATE_FILE}")
  local last_restart=$(jq -r ".[\"${container_name}\"].last_restart // 0" "${STATE_FILE}")
  local current_time=$(date +%s)
  
  # Проверяем изменение состояния
  if [ "${previous_status}" != "${current_status}" ] || [ "${previous_health}" != "${health_status}" ]; then
    if [ "${previous_status}" != "unknown" ]; then
      log_message "INFO" "Изменение состояния контейнера ${container_name}: ${previous_status}/${previous_health} -> ${current_status}/${health_status}"
      
      # Отправляем уведомление при изменении состояния на проблемное
      if [ "${current_status}" != "running" ] || [ "${health_status}" != "healthy" ] && [ "${health_status}" != "starting" ]; then
        send_notification "Проблема с контейнером ${container_name}" "Контейнер ${container_name} перешел в состояние ${current_status}/${health_status}"
      elif [ "${previous_status}" != "running" ] || [ "${previous_health}" != "healthy" ]; then
        # Контейнер восстановился
        send_notification "Контейнер ${container_name} восстановлен" "Контейнер ${container_name} перешел в состояние ${current_status}/${health_status}"
      fi
    fi
  fi
  
  # Обновляем состояние
  local json_data=$(jq \
    --arg cn "${container_name}" \
    --arg cs "${current_status}" \
    --arg ch "${health_status}" \
    --argjson rc "${restart_count}" \
    --argjson lr "${last_restart}" \
    '.[$cn] = {status: $cs, health: $ch, restart_count: $rc, last_restart: $lr}' \
    "${STATE_FILE}")
  
  echo "${json_data}" > "${STATE_FILE}"
  
  # Возвращаем информацию о необходимости перезапуска
  if [ "${current_status}" != "running" ] || [ "${health_status}" = "unhealthy" ]; then
    # Проверяем, достаточно ли времени прошло с последнего перезапуска
    local time_since_restart=$((current_time - last_restart))
    
    if [ ${restart_count} -lt ${MAX_RESTART_ATTEMPTS} ] && [ ${time_since_restart} -gt ${RESTART_COOLDOWN} ]; then
      echo "restart"
    else
      echo "no_restart"
    fi
  else
    echo "no_restart"
  fi
}

# Функция для перезапуска контейнера
restart_container() {
  local container_name=$1
  
  log_message "INFO" "Попытка перезапуска контейнера ${container_name}"
  
  # Получаем текущее состояние
  local restart_count=$(jq -r ".[\"${container_name}\"].restart_count // 0" "${STATE_FILE}")
  local current_time=$(date +%s)
  
  # Увеличиваем счетчик перезапусков
  restart_count=$((restart_count + 1))
  
  # Обновляем состояние
  local json_data=$(jq \
    --arg cn "${container_name}" \
    --argjson rc "${restart_count}" \
    --argjson lr "${current_time}" \
    '.[$cn].restart_count = $rc | .[$cn].last_restart = $lr' \
    "${STATE_FILE}")
  
  echo "${json_data}" > "${STATE_FILE}"
  
  # Перезапускаем контейнер
  docker restart "${container_name}"
  
  # Отправляем уведомление
  send_notification "Перезапуск контейнера ${container_name}" "Выполнен перезапуск контейнера ${container_name} (попытка ${restart_count}/${MAX_RESTART_ATTEMPTS})"
  
  # Ожидаем некоторое время для запуска контейнера
  sleep 10
  
  # Проверяем, успешно ли запустился контейнер
  local status=$(docker inspect --format='{{.State.Status}}' "${container_name}" 2>/dev/null || echo "Not found")
  
  if [ "${status}" = "running" ]; then
    log_message "INFO" "Контейнер ${container_name} успешно перезапущен"
  else
    log_message "ERROR" "Не удалось перезапустить контейнер ${container_name}"
    send_notification "Ошибка перезапуска ${container_name}" "Не удалось перезапустить контейнер ${container_name} после попытки ${restart_count}/${MAX_RESTART_ATTEMPTS}"
  fi
}

# Функция для проверки необходимости полного перезапуска стека
check_full_restart() {
  local unhealthy_count=0
  local total_containers=0
  
  # Получаем список всех контейнеров из docker-compose
  local containers=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q)
  
  # Подсчитываем общее количество контейнеров и количество неработающих
  for container in ${containers}; do
    total_containers=$((total_containers + 1))
    
    local container_name=$(docker inspect --format='{{.Name}}' "${container}" | sed 's/^\///')
    local status=$(docker inspect --format='{{.State.Status}}' "${container}")
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container}")
    
    if [ "${status}" != "running" ] || [ "${health}" = "unhealthy" ]; then
      unhealthy_count=$((unhealthy_count + 1))
    fi
  done
  
  # Если более 50% контейнеров не работают, рекомендуем полный перезапуск стека
  if [ ${total_containers} -gt 0 ] && [ $((unhealthy_count * 100 / total_containers)) -gt 50 ]; then
    log_message "WARN" "Более 50% контейнеров не работают или нездоровы (${unhealthy_count}/${total_containers})"
    send_notification "Критическое состояние стека" "Более 50% контейнеров (${unhealthy_count}/${total_containers}) не работают. Рекомендуется полный перезапуск стека."
    
    # Спрашиваем подтверждение, если скрипт запущен интерактивно
    if [ -t 0 ]; then
      read -p "Хотите выполнить полный перезапуск стека? [y/N] " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_message "INFO" "Выполняется полный перезапуск стека"
        docker compose -f "${DOCKER_COMPOSE_FILE}" down
        sleep 5
        docker compose -f "${DOCKER_COMPOSE_FILE}" up -d
        log_message "INFO" "Полный перезапуск стека выполнен"
        send_notification "Перезапуск стека выполнен" "Полный перезапуск стека завершен"
      fi
    else
      log_message "INFO" "Рекомендуется выполнить ручной перезапуск стека: docker compose -f ${DOCKER_COMPOSE_FILE} down && docker compose -f ${DOCKER_COMPOSE_FILE} up -d"
    fi
  fi
}

# Функция для проверки состояния контейнеров
check_containers() {
  log_message "INFO" "Начало проверки состояния контейнеров"
  
  # Проверяем существование docker-compose файла
  if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
    log_message "ERROR" "Docker Compose файл не найден: ${DOCKER_COMPOSE_FILE}"
    return 1
  fi
  
  # Получаем список всех контейнеров из docker-compose
  local containers=$(docker compose -f "${DOCKER_COMPOSE_FILE}" ps -q)
  
  if [ -z "${containers}" ]; then
    log_message "WARN" "Не найдено запущенных контейнеров из docker-compose"
    return 0
  fi
  
  # Проверяем каждый контейнер
  for container in ${containers}; do
    local container_name=$(docker inspect --format='{{.Name}}' "${container}" | sed 's/^\///')
    local status=$(docker inspect --format='{{.State.Status}}' "${container}")
    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container}")
    
    log_message "DEBUG" "Контейнер ${container_name}: статус=${status}, здоровье=${health}"
    
    # Обновляем состояние и проверяем необходимость перезапуска
    local restart_needed=$(update_container_state "${container_name}" "${status}" "${health}")
    
    if [ "${restart_needed}" = "restart" ]; then
      restart_container "${container_name}"
    fi
  done
  
  # Проверяем необходимость полного перезапуска
  check_full_restart
  
  log_message "INFO" "Проверка состояния контейнеров завершена"
}

# Функция для запуска мониторинга в цикле
run_monitoring_loop() {
  log_message "INFO" "Запуск мониторинга контейнеров (интервал проверки: ${CHECK_INTERVAL} сек)"
  
  while true; do
    check_containers
    sleep ${CHECK_INTERVAL}
  done
}

# Проверка наличия необходимых зависимостей
check_dependencies() {
  local missing_deps=0
  
  # Проверяем наличие jq
  if ! command -v jq &> /dev/null; then
    log_message "ERROR" "Отсутствует утилита jq. Установите её с помощью 'apt-get install jq'"
    missing_deps=1
  fi
  
  # Проверяем наличие docker
  if ! command -v docker &> /dev/null; then
    log_message "ERROR" "Отсутствует утилита docker. Убедитесь, что Docker установлен и доступен"
    missing_deps=1
  fi
  
  # Проверяем наличие docker-compose
  if ! command -v docker-compose &> /dev/null; then
    log_message "WARN" "Отсутствует утилита docker-compose. Используем 'docker compose' вместо 'docker-compose'"
  fi
  
  if [ ${missing_deps} -ne 0 ]; then
    return 1
  fi
  
  return 0
}

# Настройка уведомлений
setup_notifications() {
  echo -e "${YELLOW}Настройка уведомлений${NC}"
  echo "Хотите настроить уведомления по электронной почте? [y/N]"
  read -r setup_email
  
  if [[ "${setup_email}" =~ ^[Yy]$ ]]; then
    echo "Введите email для уведомлений:"
    read -r email
    NOTIFICATION_EMAIL="${email}"
    log_message "INFO" "Настроены уведомления по email: ${NOTIFICATION_EMAIL}"
  fi
  
  echo "Хотите настроить уведомления через Telegram? [y/N]"
  read -r setup_telegram
  
  if [[ "${setup_telegram}" =~ ^[Yy]$ ]]; then
    echo "Введите токен Telegram бота:"
    read -r bot_token
    echo "Введите ID чата или группы Telegram:"
    read -r chat_id
    
    TELEGRAM_BOT_TOKEN="${bot_token}"
    TELEGRAM_CHAT_ID="${chat_id}"
    
    log_message "INFO" "Настроены уведомления через Telegram"
    
    # Тестовое уведомление
    send_notification "Тестовое уведомление" "Система мониторинга контейнеров настроена и работает"
  fi
  
  # Сохраняем настройки в конфигурационный файл
  cat > "/opt/container-monitor.conf" << EOF
# Конфигурация системы мониторинга контейнеров
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
MAX_RESTART_ATTEMPTS=${MAX_RESTART_ATTEMPTS}
RESTART_COOLDOWN=${RESTART_COOLDOWN}
CHECK_INTERVAL=${CHECK_INTERVAL}
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE}"
EOF
  
  log_message "INFO" "Настройки сохранены в /opt/container-monitor.conf"
}

# Функция для настройки автозапуска при старте системы
setup_autostart() {
  echo -e "${YELLOW}Настройка автозапуска${NC}"
  echo "Хотите настроить автоматический запуск мониторинга при старте системы? [y/N]"
  read -r setup_autostart
  
  if [[ "${setup_autostart}" =~ ^[Yy]$ ]]; then
    # Создаем systemd сервис
    cat > "/etc/systemd/system/container-monitor.service" << EOF
[Unit]
Description=Docker Container Health Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/opt/container-monitor.sh --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Копируем скрипт в /opt
    cp "$0" "/opt/container-monitor.sh"
    chmod +x "/opt/container-monitor.sh"
    
    # Активируем и запускаем сервис
    systemctl daemon-reload
    systemctl enable container-monitor.service
    systemctl start container-monitor.service
    
    log_message "INFO" "Сервис container-monitor настроен и запущен"
  fi
}

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
  case $1 in
    --daemon)
      # Режим демона (постоянно работающий мониторинг)
      log_message "INFO" "Запуск в режиме демона"
      
      # Загрузка конфигурации, если она существует
      if [ -f "/opt/container-monitor.conf" ]; then
        source "/opt/container-monitor.conf"
      fi
      
      run_monitoring_loop
      exit 0
      ;;
    --once)
      # Однократная проверка
      log_message "INFO" "Запуск однократной проверки"
      
      # Загрузка конфигурации, если она существует
      if [ -f "/opt/container-monitor.conf" ]; then
        source "/opt/container-monitor.conf"
      fi
      
      check_containers
      exit 0
      ;;
    --setup)
      # Настройка мониторинга
      log_message "INFO" "Запуск настройки мониторинга"
      
      # Проверка зависимостей
      if ! check_dependencies; then
        exit 1
      fi
      
      setup_notifications
      setup_autostart
      exit 0
      ;;
    *)
      # Неизвестный аргумент
      echo "Использование: $0 [--daemon|--once|--setup]"
      echo "  --daemon    Запуск в режиме демона (постоянный мониторинг)"
      echo "  --once      Выполнить однократную проверку контейнеров"
      echo "  --setup     Настройка мониторинга и уведомлений"
      exit 1
      ;;
  esac
done

# По умолчанию запускаем интерактивную настройку или проверку
if [ -t 0 ]; then
  # Интерактивный режим
  echo -e "${GREEN}=== Система мониторинга контейнеров ===${NC}"
  echo "1) Настроить мониторинг и уведомления"
  echo "2) Выполнить однократную проверку"
  echo "3) Запустить постоянный мониторинг (в текущем терминале)"
  
  read -p "Выберите действие [1-3]: " choice
  
  case $choice in
    1)
      if ! check_dependencies; then
        exit 1
      fi
      setup_notifications
      setup_autostart
      ;;
    2)
      if ! check_dependencies; then
        exit 1
      fi
      check_containers
      ;;
    3)
      if ! check_dependencies; then
        exit 1
      fi
      
      # Загрузка конфигурации, если она существует
      if [ -f "/opt/container-monitor.conf" ]; then
        source "/opt/container-monitor.conf"
      fi
      
      run_monitoring_loop
      ;;
    *)
      echo "Неверный выбор"
      exit 1
      ;;
  esac
else
  # Неинтерактивный режим - выполняем однократную проверку
  check_dependencies && check_containers
fi
