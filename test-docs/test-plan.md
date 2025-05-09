# План масштабного тестирования стека My NoCode Stack

Версия: 1.0  
Дата: 2025-05-09  
Платформа: Ubuntu 24.04 LTS

## Содержание

1. [Введение](#1-введение)
2. [Подготовка к тестированию](#2-подготовка-к-тестированию)
3. [Тестирование базовой инфраструктуры](#3-тестирование-базовой-инфраструктуры)
4. [Тестирование отдельных компонентов](#4-тестирование-отдельных-компонентов)
5. [Тестирование интеграций между компонентами](#5-тестирование-интеграций-между-компонентами)
6. [Тестирование системы мониторинга и оповещений](#6-тестирование-системы-мониторинга-и-оповещений)
7. [Тестирование системы резервного копирования и восстановления](#7-тестирование-системы-резервного-копирования-и-восстановления)
8. [Тестирование отказоустойчивости](#8-тестирование-отказоустойчивости)
9. [Нагрузочное тестирование](#9-нагрузочное-тестирование)
10. [Проверка безопасности](#10-проверка-безопасности)
11. [Фиксация результатов и исправление ошибок](#11-фиксация-результатов-и-исправление-ошибок)

## 1. Введение

### 1.1. Цель тестирования

Целью данного тестирования является проверка работоспособности, надежности, безопасности и производительности комплексного стека технологий My NoCode Stack, развернутого на хосте с операционной системой Ubuntu 24.04 LTS.

### 1.2. Объем тестирования

Тестирование охватывает следующие компоненты:

- **n8n**: Платформа автоматизации рабочих процессов
- **PostgreSQL с pgvector**: База данных с поддержкой векторных вычислений
- **Flowise**: Платформа для создания AI-решений
- **Qdrant**: Векторная база данных для хранения и поиска векторных представлений
- **Redis**: Хранилище данных в памяти
- **WordPress**: CMS для управления контентом
- **MariaDB**: Реляционная база данных для WordPress
- **Waha**: HTTP API для интеграции с WhatsApp
- **Netdata**: Система мониторинга

А также системы повышения отказоустойчивости:

- Проверки работоспособности (healthchecks)
- Система резервного копирования и восстановления
- Система мониторинга контейнеров
- Система автоматического обслуживания

### 1.3. Ресурсы для тестирования

- Тестовый сервер с Ubuntu 24.04 LTS
- Доступ администратора (sudo)
- Доступ к Docker и Docker Compose
- Набор скриптов для тестирования и мониторинга
- Инструменты для нагрузочного тестирования (ab, wrk, siege)
- Инструменты для тестирования безопасности (nmap, nikto, owasp-zap)

## 2. Подготовка к тестированию

### 2.1. Проверка окружения

```bash
# Проверка версии OS
lsb_release -a

# Проверка версии ядра
uname -a

# Проверка Docker
docker --version
docker-compose --version

# Проверка доступного места на диске
df -h

# Проверка оперативной памяти
free -h

# Проверка загрузки CPU
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

# Проверка открытых портов
sudo netstat -tulpn | grep LISTEN
```

### 2.2. Подготовка тестовых данных

- Подготовить тестовые наборы данных для n8n workflows
- Создать тестовые векторные данные для Qdrant
- Подготовить образцы контента для WordPress
- Создать тестовые сообщения для Waha (WhatsApp)
- Подготовить тестовые сценарии для Flowise

### 2.3. Создание резервной копии перед тестированием

```bash
# Создание полной резервной копии всех данных
sudo /opt/docker-backup.sh --all

# Проверка созданной резервной копии
sudo /home/den/my-nocode-stack/backup/test-restore.sh --test
```

### 2.4. Подготовка системы мониторинга для тестирования

```bash
# Настройка временных параметров мониторинга для тестирования
sudo sed -i 's/check_interval=60/check_interval=30/' /opt/container-monitor.sh
sudo sed -i 's/notification_interval=300/notification_interval=60/' /opt/container-monitor.sh

# Перезапуск системы мониторинга с новыми параметрами
sudo systemctl restart container-monitor.service
```

## 3. Тестирование базовой инфраструктуры

### 3.1. Проверка запущенных контейнеров

```bash
# Список всех контейнеров
docker ps --all

# Проверка состояния всех сервисов
docker-compose -f /home/den/my-nocode-stack/docker-compose.yaml ps

# Проверка сетей Docker
docker network ls
docker network inspect app-network
```

### 3.2. Проверка работы Caddy (обратный прокси)

```bash
# Проверка конфигурации Caddy
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# Проверка сертификатов SSL
docker exec caddy ls -la /data/caddy/certificates

# Тестирование доступности сервисов через Caddy
for service in n8n flowise wordpress waha qdrant; do
  curl -k -I https://$service.example.com
done
```

### 3.3. Проверка доступа к Docker томам

```bash
# Список всех томов
docker volume ls

# Проверка прав доступа к основным томам
for volume in n8n_data n8n_postgres_data qdrant_storage flowise_data wordpress_data wordpress_db_data redis_data; do
  docker volume inspect $volume
done
```

### 3.4. Проверка логов системы

```bash
# Проверка логов Docker
sudo journalctl -u docker -n 100

# Проверка логов Caddy
docker logs caddy

# Проверка системных логов
sudo tail -n 100 /var/log/syslog
```

## 4. Тестирование отдельных компонентов

### 4.1. Тестирование n8n

```bash
# Проверка доступности по HTTP
curl -k -I https://n8n.example.com

# Проверка логов n8n
docker logs n8n

# Проверка подключения n8n к базе данных
docker exec n8n curl -s postgres:5432

# Тестирование базового workflow
# (Создать тестовый workflow через веб-интерфейс и запустить его)
```

#### Функциональное тестирование n8n:
- Вход в систему с учетными данными администратора
- Создание простого workflow с HTTP запросом
- Проверка выполнения workflow по расписанию
- Проверка выполнения workflow по webhook
- Тестирование подключения к внешним сервисам
- Проверка работы с переменными окружения
- Тестирование хранения учетных данных
- Проверка экспорта/импорта workflow

### 4.2. Тестирование PostgreSQL с pgvector

```bash
# Проверка состояния PostgreSQL
docker exec postgres pg_isready

# Проверка подключения к PostgreSQL
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();"

# Проверка наличия расширения pgvector
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT * FROM pg_extension WHERE extname = 'vector';"

# Тестирование создания и использования векторов
docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
CREATE TABLE IF NOT EXISTS test_vectors (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO test_vectors (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM test_vectors;
SELECT id, embedding <-> '[3,3,3]' AS distance FROM test_vectors ORDER BY distance;
DROP TABLE test_vectors;
"
```

### 4.3. Тестирование Flowise

```bash
# Проверка доступности по HTTP
curl -k -I https://flowise.example.com

# Проверка логов Flowise
docker logs flowise

# Тестирование API Flowise
curl -k -X GET https://flowise.example.com/api/v1/health
```

#### Функциональное тестирование Flowise:
- Вход в систему
- Создание тестового AI-потока
- Подключение к внешним моделям
- Тестирование обработки запросов
- Проверка сохранения конфигураций

### 4.4. Тестирование Qdrant

```bash
# Проверка доступности по HTTP
curl -k -I https://qdrant.example.com

# Проверка логов Qdrant
docker logs qdrant

# Тестирование API Qdrant
curl -k -X GET https://qdrant.example.com/health
```

#### Функциональное тестирование Qdrant:
- Создание тестовой коллекции
- Загрузка векторных данных
- Выполнение поискового запроса
- Проверка работы фильтров
- Тестирование кластеризации

### 4.5. Тестирование Redis

```bash
# Проверка состояния Redis
docker exec n8n_redis redis-cli ping

# Проверка информации о Redis
docker exec n8n_redis redis-cli info

# Тестирование базовых операций Redis
docker exec n8n_redis redis-cli set testkey "Hello World"
docker exec n8n_redis redis-cli get testkey
docker exec n8n_redis redis-cli del testkey
```

### 4.6. Тестирование WordPress

```bash
# Проверка доступности по HTTP
curl -k -I https://wordpress.example.com

# Проверка логов WordPress
docker logs wordpress

# Проверка подключения WordPress к базе данных
docker exec wordpress php -r "
\$conn = new mysqli('mariadb', '${MYSQL_USER}', '${MYSQL_PASSWORD}', '${MYSQL_DATABASE}');
echo \$conn->connect_error ? 'Failed: '.\$conn->connect_error : 'Connected successfully';
\$conn->close();
"
```

#### Функциональное тестирование WordPress:
- Вход в админ-панель
- Создание тестовой страницы и записи
- Установка и активация плагина
- Проверка настроек темы
- Тестирование комментариев
- Проверка загрузки медиафайлов

### 4.7. Тестирование MariaDB

```bash
# Проверка состояния MariaDB
docker exec mariadb mysqladmin -u${MYSQL_USER} -p${MYSQL_PASSWORD} ping

# Проверка версии MariaDB
docker exec mariadb mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT VERSION();"

# Тестирование создания тестовой таблицы
docker exec mariadb mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} -e "
CREATE TABLE IF NOT EXISTS test_table (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50));
INSERT INTO test_table (name) VALUES ('Test1'), ('Test2');
SELECT * FROM test_table;
DROP TABLE test_table;
"
```

### 4.8. Тестирование Waha

```bash
# Проверка доступности по HTTP
curl -k -I https://waha.example.com

# Проверка логов Waha
docker logs waha

# Тестирование API Waha
curl -k -X GET https://waha.example.com/api/sessions
```

#### Функциональное тестирование Waha:
- Проверка инициализации сессии WhatsApp
- Тестирование отправки сообщения
- Проверка получения статуса сообщения
- Тестирование webhook-интеграций

### 4.9. Тестирование Netdata

```bash
# Проверка доступности по HTTP
curl -k -I https://netdata.example.com

# Проверка логов Netdata
docker logs netdata

# Проверка основных метрик Netdata
curl -s -k https://netdata.example.com/api/v1/info | jq
```

#### Функциональное тестирование Netdata:
- Проверка отображения всех контейнеров
- Тестирование уведомлений
- Проверка настроек alarms
- Тестирование экспорта данных
