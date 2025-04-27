#!/bin/bash

# Получаем учетные данные из .env
SEARXNG_USERNAME=$(grep '^SEARXNG_USERNAME=' /opt/.env | cut -d'=' -f2 | tr -d '"')
SEARXNG_PASSWORD=$(grep '^SEARXNG_PASSWORD=' /opt/.env | cut -d'=' -f2 | tr -d '"')

# Проверяем, получили ли мы значения
if [ -z "$SEARXNG_USERNAME" ] || [ -z "$SEARXNG_PASSWORD" ]; then
    echo "Ошибка: Не удалось получить учетные данные SearXNG из /opt/.env"
    echo "Используем значения по умолчанию: admin G771JWUmWxLMALEa"
    SEARXNG_USERNAME="admin"
    SEARXNG_PASSWORD="G771JWUmWxLMALEa"
fi

echo "Создаем временный патч для Caddyfile..."

# Создаем патч для Caddyfile
TMP_CADDY=$(mktemp)
sudo cat /opt/Caddyfile > $TMP_CADDY

# Заменяем строки с переменными на конкретные значения
sudo sed -i "s/\$SEARXNG_USERNAME \$SEARXNG_PASSWORD/$SEARXNG_USERNAME $SEARXNG_PASSWORD/g" $TMP_CADDY

# Копируем обратно в /opt/Caddyfile
sudo cp $TMP_CADDY /opt/Caddyfile
sudo rm $TMP_CADDY

echo "Рестарт Caddy для применения изменений..."
sudo docker restart caddy

echo "Готово! Теперь проверьте доступ к SearXNG по адресу: https://searxng.flowdarth.ru"
echo "Используйте логин: $SEARXNG_USERNAME, пароль: $SEARXNG_PASSWORD"
