#!/bin/bash

# Получение переменных от основного скрипта через аргументы
DOMAIN_NAME=$1
USER_EMAIL=$2

if [ -z "$DOMAIN_NAME" ] || [ -z "$USER_EMAIL" ]; then
  echo "ОШИБКА: Не указано доменное имя или email пользователя" >&2
  echo "Использование: $0 <domain_name> <user_email>" >&2
  exit 1
fi

# Проверка свободного места на диске
FREE_SPACE=$(df -k / | awk 'NR==2 {print $4}')
MIN_SPACE=5242880  # 5GB в KB
if [ $FREE_SPACE -lt $MIN_SPACE ]; then
  echo "❌ ПРЕДУПРЕЖДЕНИЕ: Недостаточно свободного места на диске. Рекомендуется минимум 5GB." >&2
  echo "Текущее свободное место: $(df -h / | awk 'NR==2 {print $4}')" >&2
  read -p "Продолжить установку несмотря на недостаток места? (y/n): " CONTINUE
  if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
    echo "Установка прервана пользователем." >&2
    exit 1
  fi
fi

echo "Создание шаблонов и конфигурационных файлов..."

# Проверка наличия необходимых шаблонов в корневом каталоге проекта
REQUIRED_TEMPLATES=(
    "./docker-compose.yaml.template"
    "./Caddyfile.template"
)

for TPL in "${REQUIRED_TEMPLATES[@]}"; do
    if [ ! -f "$TPL" ]; then
        echo "ОШИБКА: Необходимый файл шаблона '$TPL' не найден в корневом каталоге проекта." >&2
        echo "Убедитесь, что все необходимые файлы шаблонов присутствуют." >&2
        exit 1
    fi
done
echo "Все необходимые файлы шаблонов найдены."

# Проверка наличия .env файла в корневом каталоге проекта перед подстановкой
if [ ! -f ".env" ]; then
    echo "ОШИБКА: Файл .env не найден в корневом каталоге проекта. Невозможно продолжить подстановку шаблонов." >&2
    echo "Убедитесь, что шаг 5 (генерация секретов) успешно завершен." >&2
    exit 1
fi
echo "Файл .env найден. Выполняется подстановка..."

# Экспорт всех переменных из файла .env
set -a
source ".env"
set +a

# Копирование шаблонов в рабочие файлы
# === Генерация единого docker-compose.yaml из шаблона через envsubst ===
echo "Генерируем единый docker-compose.yaml файл из шаблона..."
tmpl="docker-compose.yaml.template"
# Пропускаем если это не файл
if [ -f "$tmpl" ]; then
  # Получаем имя файла без расширения .template
  filename="${tmpl%.template}"
  output_path="/opt/$filename" # Корректный путь вывода
  echo "→ Генерируем $output_path из $tmpl ..." # Логируем правильный путь
  # Используем sudo tee для записи в /opt/
  ( set -o allexport; source .env; set +o allexport; envsubst < "$tmpl" | sudo tee "$output_path" > /dev/null )
  if [ $? -ne 0 ]; then
    echo "ОШИБКА: Не удалось обработать шаблон '$tmpl' с помощью envsubst. Проверьте файл .env и синтаксис шаблона." >&2
    sudo rm -f "$output_path" # Удаляем частично созданный файл из /opt/
    exit 1
  fi
  echo "✔ $output_path успешно создан."
  # Автоматическая проверка YAML
  if ! sudo docker compose -f "$output_path" config --quiet > /dev/null 2>&1; then
    echo "ОШИБКА: $output_path содержит синтаксические ошибки YAML!" >&2
    echo "Проверьте шаблон и значения переменных. Установка прервана." >&2
    exit 1
  fi
else
  echo "ОШИБКА: Шаблон $tmpl не найден!"
  exit 1
fi

# === Генерация Caddyfile из Caddyfile.template ===
echo "Генерируем Caddyfile из шаблона..."
CADDY_TEMPLATE="Caddyfile.template"
CADDY_OUTPUT="/opt/Caddyfile" # Корректный путь вывода

if [ ! -f "$CADDY_TEMPLATE" ]; then
  echo "ОШИБКА: $CADDY_TEMPLATE не найден!"
  exit 1
fi

# Проверяем переменные DOMAIN_NAME и USER_EMAIL
if [ -z "$DOMAIN_NAME" ]; then
  echo "ОШИБКА: Переменная DOMAIN_NAME пуста. Проверьте передачу параметров." >&2
  exit 1
fi

# Создание Caddyfile с подстановкой переменных
# Используем tempfile, чтобы избежать проблем с правами sudo
TMP_CADDY=$(mktemp)
# Интерполируем переменные в Caddyfile шаблоне
(set -o allexport; source .env; set +o allexport; USER_EMAIL="$USER_EMAIL"; DOMAIN_NAME="$DOMAIN_NAME"; envsubst < "$CADDY_TEMPLATE" > "$TMP_CADDY")

# Копируем в /opt/ с необходимыми правами
sudo cp "$TMP_CADDY" "$CADDY_OUTPUT"
sudo chmod 644 "$CADDY_OUTPUT"
sudo chown root:root "$CADDY_OUTPUT"
rm -f "$TMP_CADDY" # Удаляем временный файл

# Проверяем правильность Caddyfile
echo "Проверка синтаксиса Caddyfile..."
if ! sudo docker run --rm -v "$CADDY_OUTPUT:/etc/caddy/Caddyfile:ro" caddy:2 caddy validate --config /etc/caddy/Caddyfile; then
  echo "❌ ОШИБКА: Caddyfile содержит синтаксические ошибки!" >&2
  echo "Проверьте $CADDY_OUTPUT и исправьте ошибки." >&2
  exit 1
fi
echo "✅ Синтаксис Caddyfile проверен и корректен"

echo "✔ $CADDY_OUTPUT успешно создан."

# Копирование готовых pgvector и других файлов в конечные точки
PGVECTOR_SRC="./setup-files/pgvector-init.sql"
PGVECTOR_DST="/opt/pgvector-init.sql"

if [ -f "$PGVECTOR_SRC" ]; then
  sudo cp "$PGVECTOR_SRC" "$PGVECTOR_DST"
  sudo chmod 644 "$PGVECTOR_DST"
  echo "✔ $PGVECTOR_DST успешно скопирован."
else
  echo "⚠️ $PGVECTOR_SRC не найден. SQL-скрипт для инициализации PGVector может отсутствовать." >&2
fi

echo "✅ Шаблоны и конфигурационные файлы успешно созданы"
echo "✅ Шаблоны и конфигурационные файлы успешно созданы и скопированы"

exit 0
