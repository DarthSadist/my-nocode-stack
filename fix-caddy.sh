#!/bin/bash

# Получаем значения переменных из файла .env
if [ -f "/opt/.env" ]; then
    source /opt/.env
    echo "Загружены переменные из /opt/.env"
elif [ -f "$(pwd)/.env" ]; then
    source "$(pwd)/.env"
    echo "Загружены переменные из локального .env"
else
    echo "❌ Файл .env не найден ни в /opt/, ни в текущей директории"
    echo "Пожалуйста, укажите доменное имя и email вручную:"
    read -p "Введите доменное имя: " DOMAIN_NAME
    read -p "Введите email: " USER_EMAIL
    
    if [ -z "$DOMAIN_NAME" ] || [ -z "$USER_EMAIL" ]; then
        echo "❌ Необходимо указать доменное имя и email"
        exit 1
    fi
fi

# Создаем новый Caddyfile из шаблона
echo "Создание Caddyfile из шаблона..."
cat /home/den/my-nocode-stack/Caddyfile.template | \
    sed -e "s/\$DOMAIN_NAME/$DOMAIN_NAME/g" \
    -e "s/\$USER_EMAIL/$USER_EMAIL/g" > /tmp/Caddyfile_new

# Копируем новый файл в /opt
echo "Копирование Caddyfile в /opt..."
sudo cp /tmp/Caddyfile_new /opt/Caddyfile

# Проверяем успешность операции
if [ $? -eq 0 ]; then
    echo "Файл успешно скопирован в /opt/Caddyfile"
else
    echo "Ошибка при копировании файла в /opt/Caddyfile"
    exit 1
fi

# Перезапускаем контейнер Caddy
echo "Перезапуск контейнера Caddy..."
sudo docker restart caddy

# Проверяем успешность операции
if [ $? -eq 0 ]; then
    echo "Контейнер Caddy успешно перезапущен"
else
    echo "Ошибка при перезапуске контейнера Caddy"
    exit 1
fi

echo "Ожидаем 10 секунд, пока Caddy перезапустится..."
sleep 10

# Перезапускаем контейнер n8n для уверенности
echo "Перезапуск контейнера n8n..."
sudo docker restart n8n

# Проверяем успешность операции
if [ $? -eq 0 ]; then
    echo "Контейнер n8n успешно перезапущен"
else 
    echo "Ошибка при перезапуске контейнера n8n"
    exit 1
fi

echo "Все изменения успешно применены. Проверьте доступность n8n по адресу: https://n8n.$DOMAIN_NAME"
