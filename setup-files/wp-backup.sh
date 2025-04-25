#!/bin/bash

# Скрипт для резервного копирования WordPress

echo "================================================================="
echo "🔄 Создание резервной копии WordPress"
echo "================================================================="

# Создание директории для резервных копий
BACKUP_DIR="/opt/backups/wordpress"
sudo mkdir -p "$BACKUP_DIR"

# Проверка наличия контейнеров WordPress
if ! sudo docker ps | grep -q "wordpress"; then
  echo "❌ WordPress не запущен. Запустите сначала контейнер WordPress."
  exit 1
fi

if ! sudo docker ps | grep -q "wordpress_db"; then
  echo "❌ База данных WordPress не запущена."
  exit 1
fi

# Текущая дата для имени файла
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")

echo "Создание резервной копии базы данных..."
# Получение переменных окружения из .env файла
source /opt/.env

# Создание дампа базы данных
sudo docker exec wordpress_db sh -c "mysqldump -u${WP_DB_USER} -p${WP_DB_PASSWORD} ${WP_DB_NAME}" > "$BACKUP_DIR/wp_db_$CURRENT_DATE.sql"
if [ $? -eq 0 ]; then
  echo "✅ Дамп базы данных создан успешно: $BACKUP_DIR/wp_db_$CURRENT_DATE.sql"
else
  echo "❌ Ошибка при создании дампа базы данных"
  exit 1
fi

echo "Создание резервной копии файлов WordPress..."
# Резервное копирование файлов WordPress
sudo docker exec wordpress tar -czf - /var/www/html > "$BACKUP_DIR/wp_files_$CURRENT_DATE.tar.gz"
if [ $? -eq 0 ]; then
  echo "✅ Резервная копия файлов создана успешно: $BACKUP_DIR/wp_files_$CURRENT_DATE.tar.gz"
else
  echo "❌ Ошибка при создании резервной копии файлов"
fi

# Установка прав доступа на бэкапы
sudo chmod -R 600 "$BACKUP_DIR"
sudo chown -R root:root "$BACKUP_DIR"

# Удаление старых резервных копий (хранение только 5 последних)
echo "Удаление старых резервных копий (хранение только 5 последних)..."

# Удаление старых дампов БД
ls -t "$BACKUP_DIR"/wp_db_*.sql 2>/dev/null | tail -n +6 | xargs -r sudo rm

# Удаление старых архивов файлов
ls -t "$BACKUP_DIR"/wp_files_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r sudo rm

echo "================================================================="
echo "✅ Резервное копирование WordPress успешно завершено!"
echo "База данных: $BACKUP_DIR/wp_db_$CURRENT_DATE.sql"
echo "Файлы: $BACKUP_DIR/wp_files_$CURRENT_DATE.tar.gz"
echo "================================================================="
echo "Используйте эти файлы для восстановления WordPress при необходимости."
echo "Для автоматического резервного копирования, добавьте этот скрипт в cron:"
echo "  0 4 * * * /home/$(whoami)/cloud-local-n8n-flowise/setup-files/wp-backup.sh"
echo "Это создаст ежедневные резервные копии в 4:00."
echo "================================================================="

exit 0