#!/bin/bash

# =================================================================
# Скрипт настройки автоматического резервного копирования по расписанию
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Настройка автоматического резервного копирования ===${NC}"

# Проверка наличия root привилегий
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}Ошибка: Этот скрипт должен быть запущен с привилегиями root${NC}"
  echo "Пожалуйста, используйте 'sudo $0'"
  exit 1
fi

# Пути к файлам
BACKUP_SCRIPT="/home/den/my-nocode-stack/backup/docker-backup.sh"
INSTALL_PATH="/opt/backup"
CRON_FILE="/etc/cron.d/docker-backup"
LOG_DIR="/var/log/docker-backup"

# Создание директорий
mkdir -p "${INSTALL_PATH}" "${LOG_DIR}"

# Копирование скрипта резервного копирования
cp "${BACKUP_SCRIPT}" "${INSTALL_PATH}/"
chmod +x "${INSTALL_PATH}/$(basename ${BACKUP_SCRIPT})"

echo -e "${GREEN}Скрипт резервного копирования установлен в:${NC} ${INSTALL_PATH}/$(basename ${BACKUP_SCRIPT})"

# Выбор расписания резервного копирования
echo -e "${YELLOW}Выберите частоту автоматического резервного копирования:${NC}"
echo "1) Ежедневно (в 2:00 ночи)"
echo "2) Еженедельно (воскресенье в 3:00 ночи)"
echo "3) Ежемесячно (1-е число месяца в 4:00 ночи)"
echo "4) Пользовательское расписание"

read -p "Введите ваш выбор [1-4]: " schedule_choice

# Настройка cron-выражения в зависимости от выбранного расписания
case $schedule_choice in
  1)
    # Ежедневно в 2:00
    cron_expression="0 2 * * *"
    schedule_description="ежедневно в 2:00"
    ;;
  2)
    # Еженедельно в воскресенье в 3:00
    cron_expression="0 3 * * 0"
    schedule_description="еженедельно по воскресеньям в 3:00"
    ;;
  3)
    # Ежемесячно 1-го числа в 4:00
    cron_expression="0 4 1 * *"
    schedule_description="ежемесячно 1-го числа в 4:00"
    ;;
  4)
    # Пользовательское расписание
    echo -e "${YELLOW}Введите cron-выражение (мин час день месяц день_недели):${NC}"
    echo "Например: '0 2 * * *' для запуска в 2:00 каждый день"
    read -p "Cron-выражение: " cron_expression
    schedule_description="по пользовательскому расписанию: $cron_expression"
    ;;
  *)
    echo -e "${RED}Ошибка: Неверный выбор${NC}"
    exit 1
    ;;
esac

# Создание cron-файла
cat > "${CRON_FILE}" << EOF
# Автоматическое резервное копирование Docker-томов
${cron_expression} root ${INSTALL_PATH}/$(basename ${BACKUP_SCRIPT}) > ${LOG_DIR}/backup-\$(date +\%Y\%m\%d).log 2>&1
EOF

# Проверка, успешно ли создан cron-файл
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Cron-задание успешно настроено!${NC}"
  echo -e "Резервное копирование будет выполняться ${schedule_description}"
  echo -e "Логи будут сохраняться в директории: ${LOG_DIR}"
else
  echo -e "${RED}Ошибка: Не удалось создать cron-файл${NC}"
  exit 1
fi

# Настройка ротации логов
cat > "/etc/logrotate.d/docker-backup" << EOF
${LOG_DIR}/*.log {
  daily
  rotate 14
  compress
  missingok
  notifempty
  create 0640 root root
}
EOF

echo -e "${GREEN}Настроена ротация логов резервного копирования${NC}"

# Вывод информации о ручном запуске
echo -e "\n${YELLOW}Для ручного запуска резервного копирования выполните:${NC}"
echo -e "sudo ${INSTALL_PATH}/$(basename ${BACKUP_SCRIPT})"

echo -e "\n${GREEN}=== Настройка автоматического резервного копирования завершена ===${NC}"
