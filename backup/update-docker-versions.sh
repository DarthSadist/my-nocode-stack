#!/bin/bash

# Скрипт для обновления версий Docker-образов в шаблонах docker-compose

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Скрипт обновления версий Docker-образов ===${NC}"
echo "Этот скрипт обновит все шаблоны docker-compose с указанными стабильными версиями"

# Пути к шаблонам, которые нужно обновить
TEMPLATES=(
  "/home/den/my-nocode-stack/docker-compose.yaml.template"
  "/home/den/my-nocode-stack/backup-templates/docker-compose.yaml.template"
)

# Создание резервных копий
echo -e "${YELLOW}Создание резервных копий шаблонов...${NC}"
for template in "${TEMPLATES[@]}"; do
  if [ -f "$template" ]; then
    backup="${template}.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$template" "$backup"
    echo "Создана резервная копия: $backup"
  else
    echo -e "${RED}Ошибка: Файл $template не найден${NC}"
  fi
done

# Массивы для замены (тег latest -> конкретная версия)
CURRENT_TAGS=(
  "n8nio/n8n:latest"
  "ankane/pgvector:latest"
  "redis:alpine"
  "adminer:latest"
  "flowiseai/flowise"
  "qdrant/qdrant:latest"
  "node:18-alpine"
  "wordpress:latest"
  "devlikeapro/waha:latest"
  "containrrr/watchtower:latest"
  "netdata/netdata:latest"
)

NEW_TAGS=(
  "n8nio/n8n:1.20.0"
  "ankane/pgvector:v0.5.0"
  "redis:7.2.4-alpine"
  "adminer:4.8.1"
  "flowiseai/flowise:1.4.10"
  "qdrant/qdrant:v1.6.1"
  "node:18.18.2-alpine"
  "wordpress:6.4.2"
  "devlikeapro/waha:1.3.0"
  "containrrr/watchtower:1.6.1"
  "netdata/netdata:v1.43.0"
)

# Функция для обновления версий в файле
update_versions() {
  local file="$1"
  echo -e "${YELLOW}Обновление версий в файле: $file${NC}"
  
  # Создаем временный файл
  local tmp_file="${file}.tmp"
  
  # Копируем содержимое оригинального файла
  cp "$file" "$tmp_file"
  
  # Выполняем замены
  for i in "${!CURRENT_TAGS[@]}"; do
    current="${CURRENT_TAGS[$i]}"
    new="${NEW_TAGS[$i]}"
    sed -i "s|image: $current|image: $new|g" "$tmp_file"
    count=$(grep -c "image: $new" "$tmp_file")
    if [ $count -gt 0 ]; then
      echo -e "✅ Заменено: ${current} -> ${new} ($count раз)"
    else
      echo -e "⚠️ Замена не выполнена: ${current} -> ${new}"
    fi
  done
  
  # Проверяем наличие тега latest после замен
  latest_count=$(grep -c "image:.*latest" "$tmp_file")
  if [ $latest_count -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Внимание: в файле все еще присутствуют теги latest ($latest_count)${NC}"
    grep "image:.*latest" "$tmp_file"
  else
    echo -e "${GREEN}✅ Успех: Все теги latest заменены на фиксированные версии${NC}"
  fi
  
  # Заменяем оригинальный файл обновленным
  mv "$tmp_file" "$file"
  echo -e "${GREEN}Файл $file обновлен${NC}"
}

# Обрабатываем каждый шаблон
for template in "${TEMPLATES[@]}"; do
  if [ -f "$template" ]; then
    update_versions "$template"
    echo ""
  fi
done

echo -e "${GREEN}=== Обновление версий Docker-образов завершено ===${NC}"
echo "Не забудьте протестировать стек с новыми версиями!"
echo "Матрица совместимости доступна в файле: /home/den/my-nocode-stack/backup/compatibility-matrix.md"
