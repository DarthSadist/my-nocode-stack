# Расширенное руководство по подготовке к тестированию

## 2. Подготовка к тестированию

Правильная подготовка к тестированию критически важна для получения достоверных результатов. На этом этапе необходимо убедиться, что тестовое окружение соответствует требованиям, все необходимые инструменты установлены, и у вас есть достаточно данных для полноценного тестирования.

### 2.1. Проверка окружения

Прежде чем приступать к тестированию, необходимо тщательно проверить системное окружение для обеспечения соответствия требованиям стека.

#### 2.1.1. Проверка операционной системы

```bash
# Проверка версии и дистрибутива OS
lsb_release -a
```

**Что проверяем и почему это важно:**
- **Дистрибутив**: Убедитесь, что используется Ubuntu 24.04 LTS, для которого оптимизирован стек.
- **Версия ядра**: Проверьте, что используется современное ядро (не ниже 6.8.x для Ubuntu 24.04).
- **Codename**: Должен быть "Noble Numbat" для Ubuntu 24.04 LTS.

**Ожидаемый результат:**
```
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04 LTS
Release:        24.04
Codename:       noble
```

**Возможные проблемы и решения:**
- **Устаревшая версия ОС**: Рекомендуется обновить систему до требуемой версии, так как некоторые компоненты могут быть несовместимы с более старыми версиями.
- **Нестандартные патчи ядра**: Могут вызвать проблемы с контейнеризацией. Рекомендуется использовать стандартное ядро Ubuntu.

#### 2.1.2. Проверка ядра системы

```bash
# Проверка версии ядра
uname -a
```

**Что проверяем и почему это важно:**
- **Версия ядра**: Для Ubuntu 24.04 рекомендуется ядро не ниже 6.8.x.
- **Архитектура**: Проверяем, что система 64-битная (x86_64 или amd64).
- **Поддержка контейнеризации**: Современные ядра имеют лучшую поддержку cgroups v2 и других технологий, используемых Docker.

**Ожидаемый результат:**
```
Linux hostname 6.8.0-19-generic #19-Ubuntu SMP PREEMPT_DYNAMIC (дата и время) x86_64 x86_64 x86_64 GNU/Linux
```

**Дополнительные проверки ядра:**
```bash
# Проверка поддержки контейнеризации
grep CONFIG_NAMESPACES /boot/config-$(uname -r)

# Проверка наличия cgroup v2
mount | grep cgroup

# Проверка файловой системы OverlayFS (используется Docker)
grep overlay /proc/filesystems
```

#### 2.1.3. Проверка Docker и Docker Compose

```bash
# Проверка версии Docker
docker --version

# Проверка версии Docker Compose
docker-compose --version

# Проверка статуса службы Docker
systemctl status docker
```

**Что проверяем и почему это важно:**
- **Версия Docker**: Рекомендуется использовать Docker не ниже 24.0 для совместимости со всеми компонентами стека.
- **Версия Docker Compose**: Должна быть не ниже v2.24 для поддержки всех функций, используемых в файлах конфигурации.
- **Статус службы**: Docker должен быть активен и находиться в состоянии "running".

**Дополнительные проверки Docker:**
```bash
# Проверка запущенных контейнеров
docker ps

# Проверка доступности Docker для текущего пользователя
docker info

# Проверка настроек Docker daemon
cat /etc/docker/daemon.json
```

**Возможные проблемы и решения:**
- **Ошибка доступа к Docker**: Убедитесь, что пользователь добавлен в группу docker: `sudo usermod -aG docker $USER`.
- **Устаревшая версия Docker**: Обновите Docker и Docker Compose по [официальной инструкции](https://docs.docker.com/engine/install/ubuntu/).
- **Проблемы с бэкендом хранения**: Проверьте настройки storage driver в `/etc/docker/daemon.json`. Рекомендуется использовать `overlay2`.

#### 2.1.4. Проверка ресурсов системы

```bash
# Проверка доступного места на диске
df -h
```

**Что проверяем и почему это важно:**
- **Свободное место в корневой ФС (/)**: Требуется не менее 20 ГБ для базовых компонентов.
- **Свободное место в /var/lib/docker**: Требуется не менее 40 ГБ для контейнеров, образов и томов.
- **Свободное место в /opt/backups**: Требуется не менее 100 ГБ для хранения резервных копий.

**Рекомендуемые требования к дисковому пространству:**
- 10-15 ГБ для образов Docker
- 20-30 ГБ для данных всех контейнеров в активном состоянии
- 50-100 ГБ для резервных копий (зависит от объема данных и политики хранения)

**Дополнительная проверка файловой системы:**
```bash
# Проверка типа файловой системы
mount | grep "on / "

# Проверка атрибутов файловой системы
tune2fs -l $(mount | grep "on / " | awk '{print $1}') | grep -E "Block size|Inode count|Free inodes"
```

```bash
# Проверка оперативной памяти
free -h
```

**Что проверяем и почему это важно:**
- **Общий объем ОЗУ**: Рекомендуется не менее 8 ГБ для стабильной работы всего стека.
- **Доступная память**: В системе должно быть не менее 2 ГБ свободной памяти до запуска контейнеров.
- **Доступность SWAP**: Наличие SWAP повышает стабильность системы при пиковых нагрузках.

**Рекомендуемое распределение памяти:**
- n8n + PostgreSQL: 2-3 ГБ
- WordPress + MariaDB: 1-2 ГБ
- Flowise + Qdrant: 2-3 ГБ
- Redis, Netdata, Waha: по 0.5 ГБ каждый
- Система и другие процессы: 1-2 ГБ

**Дополнительные проверки памяти:**
```bash
# Проверка настроек SWAP
swapon --show

# Проверка ограничений лимитов системы
ulimit -a

# Проверка настроек vm.swappiness
cat /proc/sys/vm/swappiness
```

```bash
# Проверка загрузки CPU
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'
```

**Что проверяем и почему это важно:**
- **Базовая загрузка CPU**: До запуска контейнеров базовая загрузка не должна превышать 20-30%.
- **Количество ядер**: Рекомендуется не менее 4 физических ядер для стабильной работы.
- **Частота процессора**: Рекомендуется не менее 2.0 ГГц для эффективной работы.

**Дополнительные проверки CPU:**
```bash
# Проверка количества ядер/потоков
nproc

# Подробная информация о CPU
lscpu

# Проверка средней нагрузки за последние 1/5/15 минут
uptime
```

```bash
# Проверка открытых портов
sudo netstat -tulpn | grep LISTEN
```

**Что проверяем и почему это важно:**
- **Занятые порты**: Проверяем, что порты, используемые стеком (80, 443, и другие), не заняты другими сервисами.
- **Состояние сетевых сервисов**: Убедитесь, что нет конфликтующих сервисов, например, Apache или Nginx на портах 80/443.
- **Локальные привязки**: Некоторые сервисы должны быть доступны только локально (например, Redis).

**Рекомендуемые порты для проверки:**
- HTTP/HTTPS: 80, 443 (используются Caddy)
- Базы данных: 5432 (PostgreSQL), 3306 (MariaDB)
- Внутренние сервисы: 6333 (Qdrant), 6379 (Redis), 5678 (n8n) и др.

**Дополнительная проверка сети:**
```bash
# Проверка DNS-резолвинга
dig yourdomain.com
dig A yourdomain.com
dig MX yourdomain.com

# Проверка сетевых интерфейсов
ip a

# Проверка маршрутизации
ip route
```

### 2.2. Подготовка тестовых данных

Качественное тестирование требует соответствующих тестовых данных для всех компонентов системы.

#### 2.2.1. Подготовка данных для n8n

**Создание тестовых данных для n8n:**
- **Тестовый workflow**: Создайте простой рабочий процесс для проверки функциональности.
- **Тестовые данные для HTTP-запросов**: Подготовьте JSON-файлы с тестовыми данными.
- **Тестовые учетные данные**: Настройте подключения к внешним сервисам для тестирования.

**Пример создания тестового JSON для использования в n8n:**
```bash
cat > /home/den/my-nocode-stack/test-data/n8n-test-data.json << EOF
{
  "testRecords": [
    {"id": 1, "name": "Тестовый объект 1", "status": "active"},
    {"id": 2, "name": "Тестовый объект 2", "status": "inactive"},
    {"id": 3, "name": "Тестовый объект 3", "status": "pending"}
  ],
  "testConfig": {
    "apiKey": "test-api-key",
    "endpoint": "https://example.com/api",
    "retryCount": 3
  }
}
EOF
```

**Почему это важно:**
- Тестовые данные позволяют проверить функциональность n8n без взаимодействия с реальными системами
- Подготовленные заранее данные упрощают автоматизацию тестирования
- Различные типы данных позволяют проверить обработку разных сценариев

#### 2.2.2. Подготовка векторных данных для Qdrant

**Создание тестовых векторных данных:**
```bash
cat > /home/den/my-nocode-stack/test-data/qdrant-test-vectors.json << EOF
{
  "vectors": [
    {"id": "vec1", "vector": [0.1, 0.2, 0.3], "payload": {"description": "Тестовый вектор 1"}},
    {"id": "vec2", "vector": [0.4, 0.5, 0.6], "payload": {"description": "Тестовый вектор 2"}},
    {"id": "vec3", "vector": [0.7, 0.8, 0.9], "payload": {"description": "Тестовый вектор 3"}}
  ],
  "collection_config": {
    "name": "test_collection",
    "vector_size": 3,
    "distance": "Cosine"
  }
}
EOF
```

**Подготовка скрипта для загрузки векторов в Qdrant:**
```bash
cat > /home/den/my-nocode-stack/test-data/load-qdrant-vectors.sh << EOF
#!/bin/bash

# Создание тестовой коллекции
curl -X PUT "http://localhost:6333/collections/test_collection" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 3,
      "distance": "Cosine"
    }
  }'

# Загрузка тестовых векторов
curl -X PUT "http://localhost:6333/collections/test_collection/points" \
  -H "Content-Type: application/json" \
  -d @/home/den/my-nocode-stack/test-data/qdrant-test-vectors.json
EOF

chmod +x /home/den/my-nocode-stack/test-data/load-qdrant-vectors.sh
```

**Почему это важно:**
- Готовые векторные данные позволяют проверить функциональность векторного поиска
- Тестовая коллекция с известными значениями упрощает верификацию результатов
- Данные разных размерностей помогают проверить гибкость и производительность системы

#### 2.2.3. Подготовка контента для WordPress

**Создание тестового контента для WordPress:**
```bash
# Создание директории для тестовых данных WordPress
mkdir -p /home/den/my-nocode-stack/test-data/wordpress

# Создание тестовой статьи
cat > /home/den/my-nocode-stack/test-data/wordpress/test-post.html << EOF
<h1>Тестовая статья для WordPress</h1>
<p>Это тестовая статья для проверки функциональности WordPress в нашем стеке технологий.</p>
<h2>Заголовок второго уровня</h2>
<p>Проверка форматирования текста, <strong>жирный текст</strong>, <em>курсив</em> и <a href="https://example.com">ссылки</a>.</p>
<ul>
  <li>Пункт списка 1</li>
  <li>Пункт списка 2</li>
  <li>Пункт списка 3</li>
</ul>
EOF

# Скачивание тестового изображения
wget -O /home/den/my-nocode-stack/test-data/wordpress/test-image.jpg https://picsum.photos/800/600
```

**Создание скрипта для импорта в WordPress:**
```bash
cat > /home/den/my-nocode-stack/test-data/wordpress/import-content.sh << EOF
#!/bin/bash

# Установка WP-CLI в контейнер
docker exec wordpress curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
docker exec wordpress chmod +x wp-cli.phar
docker exec wordpress mv wp-cli.phar /usr/local/bin/wp

# Создание тестовой категории
docker exec wordpress wp term create category "Тестовая категория" --description="Категория для тестовых статей" --path=/var/www/html

# Импорт тестовой статьи
cat /home/den/my-nocode-stack/test-data/wordpress/test-post.html | docker exec -i wordpress wp post create --post_title="Тестовая статья" --post_status=publish --post_category="Тестовая категория" --path=/var/www/html

# Импорт тестового изображения
docker cp /home/den/my-nocode-stack/test-data/wordpress/test-image.jpg wordpress:/tmp/
docker exec wordpress wp media import /tmp/test-image.jpg --post_id=1 --title="Тестовое изображение" --path=/var/www/html
EOF

chmod +x /home/den/my-nocode-stack/test-data/wordpress/import-content.sh
```

**Почему это важно:**
- Тестовый контент позволяет оценить корректность отображения сайта
- Различные типы контента (текст, изображения, категории) помогают проверить все функции
- Автоматизированный импорт упрощает многократное тестирование

#### 2.2.4. Подготовка тестовых сообщений для Waha (WhatsApp)

**Создание тестовых сценариев для WhatsApp:**
```bash
cat > /home/den/my-nocode-stack/test-data/waha-test-messages.json << EOF
{
  "text_messages": [
    {"to": "test-number", "message": "Это тестовое сообщение 1"},
    {"to": "test-number", "message": "Это тестовое сообщение 2"},
    {"to": "test-number", "message": "Это тестовое сообщение с эмодзи 😊"}
  ],
  "media_messages": [
    {"to": "test-number", "caption": "Тестовое изображение", "media_type": "image", "media_url": "https://picsum.photos/800/600"}
  ],
  "interactive_messages": [
    {
      "to": "test-number",
      "message": "Выберите опцию:",
      "buttons": [
        {"id": "btn1", "text": "Опция 1"},
        {"id": "btn2", "text": "Опция 2"}
      ]
    }
  ]
}
EOF
```

**Создание скрипта для тестирования API Waha:**
```bash
cat > /home/den/my-nocode-stack/test-data/waha-test-api.sh << EOF
#!/bin/bash

WAHA_HOST="localhost:3000"
TARGET_NUMBER="your-test-number"  # Замените на ваш тестовый номер

# Отправка тестового текстового сообщения
curl -X POST "http://${WAHA_HOST}/api/sendText" \
  -H "Content-Type: application/json" \
  -d "{\"chatId\": \"${TARGET_NUMBER}@c.us\", \"text\": \"Тестовое сообщение через API $(date)\"}"

# Проверка статуса сообщения
sleep 2
curl -X GET "http://${WAHA_HOST}/api/messages?limit=5"
EOF

chmod +x /home/den/my-nocode-stack/test-data/waha-test-api.sh
```

**Почему это важно:**
- Тестовые сообщения разных типов позволяют проверить все функции WhatsApp API
- Заранее подготовленные сценарии упрощают проверку интеграций
- Различные форматы данных помогают выявить потенциальные проблемы

#### 2.2.5. Подготовка тестовых сценариев для Flowise

**Создание тестовых данных для Flowise:**
```bash
mkdir -p /home/den/my-nocode-stack/test-data/flowise

cat > /home/den/my-nocode-stack/test-data/flowise/test-flow.json << EOF
{
  "name": "Тестовый поток Flowise",
  "description": "Тестовый поток для проверки функциональности Flowise",
  "nodes": [
    {
      "id": "node1",
      "type": "textInput",
      "data": {
        "name": "Текстовый ввод",
        "text": "Что такое искусственный интеллект?"
      }
    },
    {
      "id": "node2",
      "type": "llmNode",
      "data": {
        "name": "AI Ответ",
        "model": "gpt-3.5-turbo",
        "temperature": 0.7
      }
    }
  ],
  "edges": [
    {
      "source": "node1",
      "target": "node2"
    }
  ]
}
EOF

# Создание тестовых данных для запросов
cat > /home/den/my-nocode-stack/test-data/flowise/test-queries.json << EOF
{
  "queries": [
    {"text": "Расскажи о технологии Docker"},
    {"text": "Что такое векторная база данных?"},
    {"text": "Как интегрировать WhatsApp с n8n?"},
    {"text": "Опиши архитектуру микросервисов"}
  ]
}
EOF
```

**Почему это важно:**
- Тестовые потоки позволяют проверить функциональность Flowise без ручной настройки
- Различные типы запросов помогают оценить качество и стабильность работы
- Готовые примеры упрощают демонстрацию возможностей системы

### 2.3. Создание резервной копии перед тестированием

Создание резервной копии перед началом тестирования — критически важный шаг, позволяющий быстро восстановить систему в случае непредвиденных проблем.

```bash
# Создание полной резервной копии всех данных
sudo /opt/docker-backup.sh --all
```

**Что выполняет эта команда:**
- Останавливает контейнеры, если необходимо (зависит от настроек)
- Создает полную резервную копию всех Docker-томов
- Сохраняет метаданные о резервной копии для последующего восстановления
- Помещает резервную копию в директорию, указанную в настройках (обычно /opt/backups)

**Важные аспекты резервного копирования:**
- Убедитесь, что процесс создания резервной копии завершился успешно
- Проверьте, что копия содержит все необходимые данные
- Запишите ID резервной копии для возможного восстановления

```bash
# Проверка созданной резервной копии
sudo /home/den/my-nocode-stack/backup/test-restore.sh --test
```

**Что проверяет эта команда:**
- Целостность файлов резервной копии
- Наличие всех необходимых компонентов
- Возможность восстановления из резервной копии
- Соответствие данных между оригиналом и резервной копией

**Дополнительные проверки резервной копии:**
```bash
# Просмотр метаданных последней резервной копии
backup_id=$(ls -tr /opt/backups/ | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$" | tail -1)
cat /opt/backups/${backup_id}/metadata.json

# Проверка размеров резервных копий томов
du -sh /opt/backups/${backup_id}/volumes/*

# Проверка прав доступа к резервным копиям
ls -la /opt/backups/${backup_id}
```

### 2.4. Подготовка системы мониторинга для тестирования

Настройка оптимальных параметров мониторинга перед тестированием позволяет получить более подробные данные о поведении системы.

```bash
# Настройка временных параметров мониторинга для тестирования
sudo sed -i 's/check_interval=60/check_interval=30/' /opt/container-monitor.sh
sudo sed -i 's/notification_interval=300/notification_interval=60/' /opt/container-monitor.sh
```

**Что изменяют эти команды:**
- **check_interval**: Уменьшение интервала проверки с 60 до 30 секунд позволяет быстрее обнаруживать проблемы
- **notification_interval**: Уменьшение интервала между уведомлениями с 5 минут до 1 минуты позволяет получать более своевременные оповещения

**Почему это важно для тестирования:**
- Более частые проверки дают более детальную картину состояния системы
- Быстрые уведомления помогают оперативно реагировать на проблемы
- Временные настройки для тестирования позволяют лучше наблюдать за состоянием системы

```bash
# Перезапуск системы мониторинга с новыми параметрами
sudo systemctl restart container-monitor.service
```

**Проверка настроек мониторинга:**
```bash
# Проверка статуса службы мониторинга
sudo systemctl status container-monitor.service

# Проверка лог-файлов мониторинга
sudo tail -n 50 /var/log/container-monitor.log

# Проверка применения новых настроек
grep "check_interval" /opt/container-monitor.sh
```

**Дополнительная настройка мониторинга:**
```bash
# Включение расширенного логирования для тестирования
sudo sed -i 's/log_level=INFO/log_level=DEBUG/' /opt/container-monitor.sh

# Настройка большего числа проверок перед перезапуском
sudo sed -i 's/retries=3/retries=2/' /opt/container-monitor.sh

# Перезапуск службы с новыми настройками
sudo systemctl restart container-monitor.service
```

**Восстановление стандартных настроек после тестирования:**
```bash
# Скрипт для восстановления настроек мониторинга
cat > /home/den/my-nocode-stack/test-data/restore-monitor-settings.sh << EOF
#!/bin/bash
sudo sed -i 's/check_interval=30/check_interval=60/' /opt/container-monitor.sh
sudo sed -i 's/notification_interval=60/notification_interval=300/' /opt/container-monitor.sh
sudo sed -i 's/log_level=DEBUG/log_level=INFO/' /opt/container-monitor.sh
sudo sed -i 's/retries=2/retries=3/' /opt/container-monitor.sh
sudo systemctl restart container-monitor.service
echo "Настройки мониторинга восстановлены"
EOF

chmod +x /home/den/my-nocode-stack/test-data/restore-monitor-settings.sh
```
