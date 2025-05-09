#!/bin/bash

# =================================================================
# Скрипт оптимизации MariaDB для отказоустойчивости
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Оптимизация MariaDB для отказоустойчивости ===${NC}"

# Путь к файлу с настройками MariaDB
MARIADB_CONF="/home/den/my-nocode-stack/backup/mariadb-config.cnf"

# Создание файла с оптимизированными настройками MariaDB
cat > "${MARIADB_CONF}" << EOF
[mysqld]
# Основные настройки производительности
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_stats_on_metadata = 0

# Оптимизация для SSD
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 4
innodb_write_io_threads = 4
innodb_flush_neighbors = 0

# Кэширование и буферы
max_connections = 100
thread_cache_size = 128
table_open_cache = 4000
query_cache_type = 0
query_cache_size = 0
query_cache_limit = 0

# Отказоустойчивость и восстановление
sync_binlog = 1
binlog_format = ROW
binlog_expire_logs_seconds = 604800
max_binlog_size = 100M
skip_name_resolve = ON
explicit_defaults_for_timestamp = 1
max_allowed_packet = 16M

# Оптимизация для WordPress
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
transaction_isolation = READ-COMMITTED

# Настройки для восстановления после сбоев
innodb_fast_shutdown = 0
innodb_doublewrite = 1
innodb_checksums = 1
innodb_strict_mode = 1
innodb_data_file_path = ibdata1:12M:autoextend

# Временные задержки для повышения стабильности
wait_timeout = 300
interactive_timeout = 300
net_read_timeout = 30
net_write_timeout = 60
lock_wait_timeout = 120

# Логирование для диагностики проблем
slow_query_log = 1
slow_query_log_file = /var/lib/mysql/slow-query.log
long_query_time = 2
log_error = /var/lib/mysql/error.log
general_log = 0
EOF

echo -e "${GREEN}Файл с оптимизированными настройками MariaDB создан: ${MARIADB_CONF}${NC}"

# Создание скрипта инициализации для docker-entrypoint-initdb.d
cat > "/home/den/my-nocode-stack/backup/mariadb-init-script.sh" << 'EOF'
#!/bin/bash
set -e

echo "Применение оптимизированных настроек MariaDB..."

# Создание директории для резервных копий
mkdir -p /var/lib/mysql/backups
chown mysql:mysql /var/lib/mysql/backups

# Создание скрипта для резервного копирования
cat > /var/lib/mysql/backup-mysql.sh << 'SCRIPT'
#!/bin/bash
BACKUP_DIR="/var/lib/mysql/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="$MYSQL_DATABASE"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

# Создание резервной копии
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --opt "$DB_NAME" | gzip > "$BACKUP_FILE"

# Удаление старых резервных копий (оставляем последние 5)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -type f -mtime +7 -delete
# Если резервных копий больше 5, удаляем лишние (самые старые)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -type f -printf '%T@ %p\n' | sort -n | head -n -5 | cut -d' ' -f2- | xargs rm -f 2>/dev/null || true
SCRIPT

chmod +x /var/lib/mysql/backup-mysql.sh

# Настройка cron для регулярного резервного копирования
if [ -d /etc/cron.d ]; then
  echo "0 2 * * * mysql /var/lib/mysql/backup-mysql.sh >/dev/null 2>&1" > /etc/cron.d/mysql-backup
  chmod 0644 /etc/cron.d/mysql-backup
else
  # Если директория cron.d недоступна, выводим инструкции для ручной настройки
  echo "Для настройки автоматического резервного копирования вручную добавьте в crontab:"
  echo "0 2 * * * /var/lib/mysql/backup-mysql.sh >/dev/null 2>&1"
fi

# Создание скрипта для проверки и восстановления MyISAM таблиц при запуске
cat > /var/lib/mysql/check-tables.sh << 'SCRIPT'
#!/bin/bash
# Получение списка всех баз данных
databases=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)")

# Проверка и восстановление таблиц MyISAM для каждой базы данных
for db in $databases; do
  echo "Проверка таблиц в базе данных $db"
  tables=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE $db; SHOW TABLES;" | grep -v "Tables_in")
  
  for table in $tables; do
    # Получение типа таблицы
    engine=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table';" | grep -v "ENGINE")
    
    # Проверка и восстановление только для таблиц MyISAM
    if [ "$engine" = "MyISAM" ]; then
      echo "Проверка MyISAM таблицы $db.$table"
      mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CHECK TABLE $db.$table;"
      
      # Если есть проблемы, восстанавливаем таблицу
      if [ $? -ne 0 ]; then
        echo "Восстановление таблицы $db.$table"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "REPAIR TABLE $db.$table;"
      fi
    fi
  done
done
SCRIPT

chmod +x /var/lib/mysql/check-tables.sh

# Настройка запуска скрипта проверки при старте
echo "Скрипт проверки таблиц создан: /var/lib/mysql/check-tables.sh"
echo "Рекомендуется запускать его после восстановления системы или при подозрении на проблемы с базой данных"

echo "Оптимизация MariaDB для отказоустойчивости завершена"
EOF

chmod +x "/home/den/my-nocode-stack/backup/mariadb-init-script.sh"
echo -e "${GREEN}Скрипт инициализации MariaDB создан: /home/den/my-nocode-stack/backup/mariadb-init-script.sh${NC}"

# Модификация docker-compose для добавления настроек MariaDB
echo -e "\n${YELLOW}Для применения настроек MariaDB необходимо обновить docker-compose.yaml${NC}"

# Создание скрипта для модификации docker-compose
cat > "/home/den/my-nocode-stack/backup/update-db-volumes.sh" << 'EOF'
#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Пути к файлам
DOCKER_COMPOSE="/opt/docker-compose.yaml"
BACKUP_COMPOSE="/opt/docker-compose.yaml.bak.$(date +%Y%m%d%H%M%S)"
MARIADB_CONF="/opt/mariadb-config.cnf"
MARIADB_INIT="/opt/mariadb-init-script.sh"
POSTGRES_CONF="/opt/postgres-config.sql"
POSTGRES_INIT="/opt/postgres-init-script.sh"

# Создание резервной копии docker-compose.yaml
echo -e "${YELLOW}Создание резервной копии docker-compose.yaml...${NC}"
cp "${DOCKER_COMPOSE}" "${BACKUP_COMPOSE}"
echo -e "${GREEN}Резервная копия создана: ${BACKUP_COMPOSE}${NC}"

# Копирование файлов конфигурации в /opt
echo -e "${YELLOW}Копирование файлов конфигурации...${NC}"
cp "/home/den/my-nocode-stack/backup/mariadb-config.cnf" "${MARIADB_CONF}"
cp "/home/den/my-nocode-stack/backup/mariadb-init-script.sh" "${MARIADB_INIT}"
cp "/home/den/my-nocode-stack/backup/postgres-config.sql" "${POSTGRES_CONF}"
cp "/home/den/my-nocode-stack/backup/postgres-init-script.sh" "${POSTGRES_INIT}"
chmod +x "${MARIADB_INIT}" "${POSTGRES_INIT}"

# Функция для добавления volume в docker-compose
add_volume() {
  local service=$1
  local volume=$2
  local compose_file=$3
  
  # Проверяем наличие volume
  if grep -q "${volume}" "${compose_file}"; then
    echo -e "${YELLOW}Volume ${volume} уже существует для сервиса ${service}, пропускаем${NC}"
    return 0
  fi
  
  # Находим раздел volumes для сервиса
  local service_start=$(grep -n "^ \+${service}:" "${compose_file}" | cut -d: -f1)
  
  if [ -z "${service_start}" ]; then
    echo -e "${RED}Сервис ${service} не найден в ${compose_file}${NC}"
    return 1
  fi
  
  # Находим раздел volumes внутри сервиса
  local volumes_start=$(tail -n +${service_start} "${compose_file}" | grep -n "^ \+volumes:" | head -1 | cut -d: -f1)
  
  if [ -z "${volumes_start}" ]; then
    echo -e "${RED}Раздел volumes не найден для сервиса ${service}${NC}"
    return 1
  fi
  
  # Вычисляем абсолютный номер строки volumes
  volumes_start=$((service_start + volumes_start - 1))
  
  # Добавляем volume
  sed -i "${volumes_start}a\\      - ${volume}" "${compose_file}"
  
  echo -e "${GREEN}Volume ${volume} добавлен для сервиса ${service}${NC}"
  return 0
}

# Обновление docker-compose.yaml
echo -e "${YELLOW}Обновление docker-compose.yaml...${NC}"

# Добавление volumes для MariaDB
add_volume "wordpress_db" "${MARIADB_CONF}:/etc/mysql/conf.d/mariadb-custom.cnf:ro" "${DOCKER_COMPOSE}"
add_volume "wordpress_db" "${MARIADB_INIT}:/docker-entrypoint-initdb.d/mariadb-init-script.sh:ro" "${DOCKER_COMPOSE}"

# Добавление volumes для PostgreSQL
add_volume "postgres" "${POSTGRES_CONF}:/docker-entrypoint-initdb.d/postgres-config.sql:ro" "${DOCKER_COMPOSE}"
add_volume "postgres" "${POSTGRES_INIT}:/docker-entrypoint-initdb.d/postgres-init-script.sh:ro" "${DOCKER_COMPOSE}"

echo -e "${GREEN}Файл docker-compose.yaml успешно обновлен${NC}"
echo -e "${YELLOW}Для применения изменений необходимо перезапустить базы данных:${NC}"
echo "sudo docker compose -f ${DOCKER_COMPOSE} restart postgres wordpress_db"
EOF

chmod +x "/home/den/my-nocode-stack/backup/update-db-volumes.sh"
echo -e "${GREEN}Скрипт обновления docker-compose создан: /home/den/my-nocode-stack/backup/update-db-volumes.sh${NC}"

# Инструкции по применению
echo -e "\n${YELLOW}Для применения оптимизаций баз данных выполните следующие действия:${NC}"
echo "1. Выполните скрипт обновления docker-compose:"
echo "   sudo /home/den/my-nocode-stack/backup/update-db-volumes.sh"
echo ""
echo "2. Перезапустите базы данных для применения настроек:"
echo "   sudo docker compose -f /opt/docker-compose.yaml restart postgres wordpress_db"
echo ""
echo -e "${GREEN}Оптимизация MariaDB для отказоустойчивости завершена${NC}"
