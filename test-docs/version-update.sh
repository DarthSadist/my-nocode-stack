#!/bin/bash
# Скрипт для управления версиями документации
# Сохраните как ~/my-nocode-stack/test-docs/version-update.sh

VERSION_FILE="$HOME/my-nocode-stack/test-docs/version-control.md"
CHANGELOG_FILE="$HOME/my-nocode-stack/test-docs/changelog.md"

# Функция для извлечения текущей версии
get_current_version() {
  grep "| [0-9]\.[0-9]\.[0-9] |" "$VERSION_FILE" | tail -1 | awk -F'|' '{print $2}' | tr -d ' '
}

# Функция для обновления версии
update_version() {
  local current_version=$(get_current_version)
  local major=$(echo $current_version | cut -d. -f1)
  local minor=$(echo $current_version | cut -d. -f2)
  local patch=$(echo $current_version | cut -d. -f3)
  
  case "$1" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      echo "Некорректный тип версии. Используйте: major, minor или patch"
      exit 1
      ;;
  esac
  
  echo "${major}.${minor}.${patch}"
}

# Проверка аргументов
if [ $# -lt 2 ]; then
  echo "Использование: $0 [major|minor|patch] \"Описание изменений\""
  exit 1
fi

VERSION_TYPE="$1"
DESCRIPTION="$2"
AUTHOR="${3:-Администратор}"

# Обновление версии
NEW_VERSION=$(update_version "$VERSION_TYPE")
CURRENT_DATE=$(date +%Y-%m-%d)

# Обновление таблицы версий
NEW_ENTRY="| $NEW_VERSION  | $CURRENT_DATE  | $AUTHOR   | $DESCRIPTION |"
sed -i "/| Версия | Дата/a $NEW_ENTRY" "$VERSION_FILE"

# Обновление журнала изменений
if [ -f "$CHANGELOG_FILE" ]; then
  echo -e "## Версия $NEW_VERSION - $CURRENT_DATE\n\n### Автор: $AUTHOR\n\n$DESCRIPTION\n\n---\n\n$(cat $CHANGELOG_FILE)" > "$CHANGELOG_FILE.tmp"
  mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"
else
  echo -e "# Журнал изменений документации по тестированию\n\n## Версия $NEW_VERSION - $CURRENT_DATE\n\n### Автор: $AUTHOR\n\n$DESCRIPTION\n" > "$CHANGELOG_FILE"
fi

echo "Версия обновлена до $NEW_VERSION"
echo "Описание: $DESCRIPTION"
echo "Таблица версий и журнал изменений обновлены"

# Делаем скрипт исполняемым
chmod +x $0
