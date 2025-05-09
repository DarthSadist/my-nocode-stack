#!/bin/bash

# =================================================================
# Скрипт оптимизации PostgreSQL для отказоустойчивости
# Версия: 1.0
# =================================================================

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Оптимизация PostgreSQL для отказоустойчивости ===${NC}"

# Путь к файлу с настройками PostgreSQL
POSTGRES_CONF="/opt/postgres-config.sql"

# Создание файла с оптимизированными настройками PostgreSQL
cat > "${POSTGRES_CONF}" << EOF
-- Оптимизация PostgreSQL для отказоустойчивости

-- Основные настройки производительности и отказоустойчивости
ALTER SYSTEM SET max_connections = '100';
ALTER SYSTEM SET shared_buffers = '512MB';
ALTER SYSTEM SET effective_cache_size = '1536MB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = '100';
ALTER SYSTEM SET random_page_cost = '1.1';
ALTER SYSTEM SET effective_io_concurrency = '200';
ALTER SYSTEM SET work_mem = '5242kB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET max_worker_processes = '4';
ALTER SYSTEM SET max_parallel_workers_per_gather = '2';
ALTER SYSTEM SET max_parallel_workers = '4';
ALTER SYSTEM SET max_parallel_maintenance_workers = '2';

-- Настройки для повышения надежности
ALTER SYSTEM SET synchronous_commit = 'on';
ALTER SYSTEM SET full_page_writes = 'on';
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/data/archive/%f && cp %p /var/lib/postgresql/data/archive/%f';
ALTER SYSTEM SET archive_timeout = '1h';

-- Настройки для восстановления после сбоев
ALTER SYSTEM SET restart_after_crash = 'on';
ALTER SYSTEM SET old_snapshot_threshold = '1h';
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET wal_keep_segments = '32';

-- Оптимизация для pgvector
ALTER SYSTEM SET maintenance_io_concurrency = '200';

-- Создание директории для архивов WAL
CREATE OR REPLACE FUNCTION create_archive_dir() RETURNS void AS \$\$
BEGIN
    PERFORM pg_exec('mkdir -p /var/lib/postgresql/data/archive');
    PERFORM pg_exec('chmod 700 /var/lib/postgresql/data/archive');
END;
\$\$ LANGUAGE plpgsql;

SELECT create_archive_dir();

-- Проверка расширения pgvector и создание, если необходимо
CREATE EXTENSION IF NOT EXISTS vector;

-- Сохранение настроек
SELECT pg_reload_conf();
EOF

echo -e "${GREEN}Файл с оптимизированными настройками PostgreSQL создан: ${POSTGRES_CONF}${NC}"

# Создание скрипта инициализации для docker-entrypoint-initdb.d
cat > "/home/den/my-nocode-stack/backup/postgres-init-script.sh" << 'EOF'
#!/bin/bash
set -e

echo "Создание директории для архивов WAL..."
mkdir -p /var/lib/postgresql/data/archive
chmod 700 /var/lib/postgresql/data/archive

echo "Применение оптимизированных настроек PostgreSQL..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /docker-entrypoint-initdb.d/postgres-config.sql

echo "Настройка автоматического резервного копирования..."
cat > /var/lib/postgresql/backup-script.sh << 'SCRIPT'
#!/bin/bash
BACKUP_DIR="/var/lib/postgresql/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="$POSTGRES_DB"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

# Создание резервной копии
pg_dump -U "$POSTGRES_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Удаление старых резервных копий (оставляем только последние 5)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -type f -printf '%T@ %p\n' | sort -n | head -n -5 | cut -d' ' -f2- | xargs rm -f
SCRIPT

chmod +x /var/lib/postgresql/backup-script.sh

# Добавление задания в crontab
echo "0 3 * * * /var/lib/postgresql/backup-script.sh >> /var/lib/postgresql/data/backup.log 2>&1" > /var/spool/cron/crontabs/postgres
chmod 600 /var/spool/cron/crontabs/postgres

echo "Оптимизация PostgreSQL для отказоустойчивости завершена"
EOF

chmod +x "/home/den/my-nocode-stack/backup/postgres-init-script.sh"
echo -e "${GREEN}Скрипт инициализации PostgreSQL создан: /home/den/my-nocode-stack/backup/postgres-init-script.sh${NC}"

# Инструкции по внедрению
echo -e "\n${YELLOW}Для применения оптимизаций PostgreSQL выполните следующие действия:${NC}"
echo "1. Скопируйте файлы в директорию /opt:"
echo "   sudo cp ${POSTGRES_CONF} /opt/"
echo "   sudo cp /home/den/my-nocode-stack/backup/postgres-init-script.sh /opt/"
echo ""
echo "2. Добавьте следующие строки в docker-compose.yaml в раздел volumes для сервиса postgres:"
echo "   - /opt/postgres-config.sql:/docker-entrypoint-initdb.d/postgres-config.sql:ro"
echo "   - /opt/postgres-init-script.sh:/docker-entrypoint-initdb.d/postgres-init-script.sh:ro"
echo ""
echo "3. Перезапустите PostgreSQL для применения настроек:"
echo "   sudo docker compose -f /opt/docker-compose.yaml down postgres"
echo "   sudo docker compose -f /opt/docker-compose.yaml up -d postgres"
echo ""
echo -e "${GREEN}Оптимизация PostgreSQL для отказоустойчивости завершена${NC}"
