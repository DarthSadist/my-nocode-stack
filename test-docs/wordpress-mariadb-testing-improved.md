# Расширенное руководство по тестированию WordPress и MariaDB

## 4.5. Тестирование WordPress и MariaDB

WordPress в сочетании с MariaDB является важным компонентом вашего стека, предоставляя гибкую платформу для создания контента, управления веб-сайтом и интеграции с другими сервисами. Тщательное тестирование этого комплекса необходимо для обеспечения стабильной работы и безопасности всей системы.

### 4.5.1. Проверка доступности WordPress и MariaDB

#### 4.5.1.1. Проверка доступности WordPress

```bash
# Проверка доступности по HTTP
curl -k -I https://wordpress.yourdomain.com
```

**Что проверяем и почему это важно:**
- **Код ответа HTTP**: Должен быть 200 OK. Коды 5xx указывают на проблемы с сервером.
- **Заголовки ответа**: Проверяем наличие правильных заголовков безопасности и кеширования.
- **Время отклика**: Быстрый отклик (менее 1 секунды) указывает на отсутствие проблем с производительностью.

**Ожидаемый результат:**
```
HTTP/2 200 
server: Caddy
content-type: text/html; charset=UTF-8
date: Fri, 09 May 2025 05:04:00 GMT
strict-transport-security: max-age=31536000; includeSubDomains
x-powered-by: PHP/8.2.x
```

**Возможные проблемы и их решения:**
- **503 Service Unavailable**: Проверьте статус контейнера WordPress: `docker ps | grep wordpress`.
- **504 Gateway Timeout**: Проверьте логи WordPress: `docker logs wordpress`.
- **Connection refused**: Проверьте настройки Caddy и сетевые подключения.

#### 4.5.1.2. Проверка доступности MariaDB

```bash
# Проверка соединения с MariaDB
docker exec mariadb mysqladmin -u$MYSQL_USER -p$MYSQL_PASSWORD ping
```

**Ожидаемый результат:**
```
mysqld is alive
```

**Альтернативная проверка через MySQL клиент:**
```bash
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1;"
```

**Ожидаемый результат:**
```
1
1
```

### 4.5.2. Проверка логов WordPress и MariaDB

#### 4.5.2.1. Проверка логов WordPress

```bash
# Проверка логов WordPress
docker logs wordpress --tail 100
```

**Что искать в логах:**
- **Ошибки PHP**: Обратите внимание на сообщения с "PHP Fatal error", "PHP Warning", "PHP Notice".
- **Ошибки WordPress**: Ищите сообщения о проблемах с плагинами, темами или базой данных.
- **Проблемы соединения**: Обратите внимание на ошибки подключения к MariaDB или другим сервисам.

**Полезные команды для анализа логов:**
```bash
# Поиск ошибок в логах WordPress
docker logs wordpress 2>&1 | grep -i "error\|fatal\|warning\|notice"

# Проверка последних записей и мониторинг в реальном времени
docker logs --tail 50 wordpress
docker logs -f wordpress
```

#### 4.5.2.2. Проверка логов MariaDB

```bash
# Проверка логов MariaDB
docker logs mariadb --tail 100
```

**Что искать в логах:**
- **Ошибки инициализации**: Сообщения об ошибках при запуске.
- **Проблемы с подключениями**: Ошибки аутентификации или превышение лимита соединений.
- **Ошибки запросов**: Сообщения о проблемных SQL-запросах.
- **Проблемы с производительностью**: Сообщения о медленных запросах.

**Полезные команды для анализа логов:**
```bash
# Поиск ошибок в логах MariaDB
docker logs mariadb 2>&1 | grep -i "error\|warning\|denied\|timeout"

# Проверка последних записей и мониторинг в реальном времени
docker logs --tail 50 mariadb
docker logs -f mariadb
```

### 4.5.3. Тестирование базы данных MariaDB

#### 4.5.3.1. Проверка подключения WordPress к MariaDB

```bash
# Проверка соединения WordPress с MariaDB
docker exec wordpress php -r "try {\
    new PDO('mysql:host=mariadb;dbname=$MYSQL_DATABASE', '$MYSQL_USER', '$MYSQL_PASSWORD');\
    echo 'WordPress успешно подключился к MariaDB\n';\
} catch (PDOException \$e) {\
    echo 'Ошибка подключения: ' . \$e->getMessage();\
}"
```

#### 4.5.3.2. Проверка состояния базы данных WordPress

```bash
# Проверка состояния таблиц WordPress
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW TABLES FROM $MYSQL_DATABASE;"
```

**Что проверять:**
- **Наличие всех таблиц WordPress**: Должны присутствовать стандартные таблицы WordPress (wp_posts, wp_users и т.д.).
- **Консистентность базы данных**: Проверьте целостность таблиц.

```bash
# Проверка целостности таблиц
docker exec mariadb mysqlcheck -u$MYSQL_USER -p$MYSQL_PASSWORD --check $MYSQL_DATABASE
```

#### 4.5.3.3. Диагностика проблем с производительностью MariaDB

```bash
# Проверка статуса сервера MariaDB
docker exec mariadb mysqladmin -u$MYSQL_USER -p$MYSQL_PASSWORD status

# Просмотр статистики производительности
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW GLOBAL STATUS;"

# Проверка текущих настроек
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES;"

# Проверка активных процессов
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW PROCESSLIST;"
```

**Что анализировать:**
- **Количество соединений**: Слишком много открытых соединений может указывать на проблемы.
- **Кеширование запросов**: Проверьте эффективность кеша запросов.
- **Блокировки таблиц**: Длительные блокировки могут вызывать задержки.
- **Медленные запросы**: Анализируйте логи медленных запросов.

```bash
# Проверка настроек медленных запросов
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW VARIABLES LIKE 'slow_query%';"

# Включение журнала медленных запросов (если не включен)
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 1;"
```

### 4.5.4. Функциональное тестирование WordPress

#### 4.5.4.1. Тестирование административного входа

```bash
# Проверка страницы входа
curl -k -I https://wordpress.yourdomain.com/wp-login.php
```

**Тестирование через интерфейс:**
1. Откройте https://wordpress.yourdomain.com/wp-login.php в браузере
2. Введите корректные учетные данные администратора
3. Проверьте успешный вход и доступ к админ-панели
4. Проверьте корректное отображение всех элементов админ-панели

**Тестирование безопасности входа:**
1. Попробуйте ввести неверные учетные данные
2. Проверьте, что система правильно обрабатывает неудачные попытки входа
3. Проверьте механизмы защиты от брутфорс-атак (если установлены)

#### 4.5.4.2. Тестирование основных функций

**Создание и редактирование контента:**
1. Создайте новую запись (пост)
2. Добавьте к ней медиафайл (изображение)
3. Опубликуйте запись
4. Проверьте корректное отображение на сайте
5. Отредактируйте запись
6. Проверьте сохранение изменений

**Управление пользователями:**
1. Создайте нового тестового пользователя
2. Установите различные уровни прав
3. Проверьте работу ограничений прав доступа
4. Удалите тестового пользователя

**Управление темами и плагинами:**
1. Проверьте активацию/деактивацию плагинов
2. Проверьте возможность переключения тем
3. Протестируйте обновление плагинов (если возможно)

#### 4.5.4.3. Тестирование API WordPress

```bash
# Проверка доступности REST API
curl -k https://wordpress.yourdomain.com/wp-json/
```

**Что проверять:**
- **Доступность API**: API должен отвечать с кодом 200
- **Наличие ожидаемых эндпоинтов**: Проверьте основные эндпоинты WordPress API
- **Аутентификация API**: Проверьте работу защищенных эндпоинтов

```bash
# Получение списка постов через API
curl -k https://wordpress.yourdomain.com/wp-json/wp/v2/posts

# Проверка защищенных эндпоинтов (требуется аутентификация)
curl -k -X POST https://wordpress.yourdomain.com/wp-json/jwt-auth/v1/token \
  --data "username=admin&password=your_password"
```

### 4.5.5. Тестирование производительности

#### 4.5.5.1. Базовые тесты производительности WordPress

```bash
# Простой тест времени загрузки главной страницы
time curl -k -s https://wordpress.yourdomain.com > /dev/null

# Тестирование кеширования (повторный запрос должен быть быстрее)
time curl -k -s https://wordpress.yourdomain.com > /dev/null
```

**Инструменты для более детального анализа производительности:**
- WordPress Site Health (Доступно в админ-панели: Инструменты > Здоровье сайта)
- Query Monitor плагин (установите для детального анализа запросов)

#### 4.5.5.2. Нагрузочное тестирование

```bash
# Скрипт для простого нагрузочного тестирования
cat > /tmp/wordpress-load-test.sh << 'EOF'
#!/bin/bash

URL="https://wordpress.yourdomain.com"
REQUESTS=50
CONCURRENT=10

echo "Запуск тестирования с $REQUESTS запросами ($CONCURRENT параллельных)"

# Используем Apache Bench, если установлен
if command -v ab &> /dev/null; then
    ab -n $REQUESTS -c $CONCURRENT -k -H "Accept-Encoding: gzip, deflate" $URL/
    exit 0
fi

# Альтернативный вариант с curl
for i in $(seq 1 $CONCURRENT); do
  (
    for j in $(seq 1 $(($REQUESTS / $CONCURRENT))); do
      start=$(date +%s.%N)
      curl -k -s -o /dev/null -w "%{http_code}" $URL/ > /dev/null
      end=$(date +%s.%N)
      runtime=$(echo "$end - $start" | bc -l)
      echo "Запрос $((($i-1)*($REQUESTS/$CONCURRENT) + $j)): время $runtime сек"
    done
  ) &
done

wait
echo "Тестирование завершено!"
EOF

chmod +x /tmp/wordpress-load-test.sh
```

**Что анализировать:**
- **Среднее время отклика**: Должно быть менее 1-2 секунд
- **Стабильность под нагрузкой**: Отсутствие ошибок при параллельных запросах
- **Использование ресурсов сервера**: Мониторинг CPU, памяти и дисковых операций

### 4.5.6. Тестирование безопасности

#### 4.5.6.1. Базовые проверки безопасности

```bash
# Проверка версии WordPress
curl -k -s https://wordpress.yourdomain.com | grep -o "WordPress [0-9.]*"

# Проверка заголовков безопасности
curl -k -I https://wordpress.yourdomain.com | grep -E "(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security)"

# Проверка доступа к критическим файлам (должны быть защищены)
curl -k -I https://wordpress.yourdomain.com/wp-config.php
```

**Важные аспекты безопасности для проверки:**
- **HTTPS**: Проверьте корректную настройку SSL/TLS
- **Скрытие версии WordPress**: Версия не должна отображаться в исходном коде
- **Обновления**: WordPress и все плагины должны быть обновлены
- **Права доступа к файлам**: Проверьте корректные права внутри контейнера

```bash
# Проверка прав доступа к файлам WordPress
docker exec wordpress find /var/www/html -type f -name "wp-config.php" -exec ls -l {} \;
```

#### 4.5.6.2. Расширенные проверки безопасности

**Сканирование уязвимостей WordPress (требуется WPScan):**
```bash
# Установка wpscan (если не установлен)
docker run -it --rm wpscanteam/wpscan --url https://wordpress.yourdomain.com --api-token YOUR_API_TOKEN
```

**Проверка безопасности базы данных:**
```bash
# Проверка анонимных пользователей MySQL (не должно быть)
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user, host FROM mysql.user WHERE user='';"

# Проверка привилегий пользователей
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT user, host, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv FROM mysql.user;"
```

### 4.5.7. Тестирование резервного копирования и восстановления

#### 4.5.7.1. Резервное копирование WordPress

```bash
# Резервное копирование файлов WordPress
docker exec wordpress tar -czvf /tmp/wordpress-files-$(date +%Y%m%d).tar.gz -C /var/www/html .

# Копирование архива на хост
docker cp wordpress:/tmp/wordpress-files-$(date +%Y%m%d).tar.gz ./backups/

# Резервное копирование базы данных
docker exec mariadb mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --all-databases > ./backups/mariadb-full-$(date +%Y%m%d).sql
```

#### 4.5.7.2. Тестирование восстановления

```bash
# Восстановление базы данных из резервной копии
cat ./backups/mariadb-full-20250509.sql | docker exec -i mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD

# Восстановление файлов (в тестовый каталог для проверки)
docker exec wordpress mkdir -p /tmp/restore-test
docker cp ./backups/wordpress-files-20250509.tar.gz wordpress:/tmp/
docker exec wordpress tar -xzvf /tmp/wordpress-files-20250509.tar.gz -C /tmp/restore-test
```

**Что проверять при восстановлении:**
- **Целостность данных**: Все файлы и таблицы должны быть восстановлены корректно
- **Функциональность**: WordPress должен работать после восстановления
- **Консистентность**: Содержимое сайта должно соответствовать моменту создания резервной копии

### 4.5.8. Тестирование интеграции с другими компонентами

#### 4.5.8.1. Интеграция WordPress с n8n

```bash
# Проверка доступности WordPress REST API из n8n
docker exec n8n curl -k https://wordpress.yourdomain.com/wp-json/

# Создание примера workflow в n8n для работы с WordPress
# (Через UI или API)
```

**Сценарии для тестирования интеграции:**
1. Автоматическое создание постов в WordPress из n8n
2. Обработка новых комментариев через n8n
3. Синхронизация данных между WordPress и другими системами

#### 4.5.8.2. Интеграция WordPress с другими сервисами

```bash
# Проверка подключения к Redis (если используется для кеширования)
docker exec wordpress redis-cli -h redis ping

# Проверка доступности через внешний прокси (Caddy)
curl -k -I https://wordpress.yourdomain.com
```

### 4.5.9. Тестирование восстановления после сбоев

```bash
# Имитация сбоя WordPress
docker stop wordpress

# Перезапуск службы
docker start wordpress

# Проверка работоспособности после перезапуска
sleep 10
curl -k -I https://wordpress.yourdomain.com
```

**Сценарии для тестирования отказоустойчивости:**
1. Перезапуск контейнера WordPress
2. Перезапуск контейнера MariaDB
3. Одновременный перезапуск нескольких сервисов
4. Проверка автоматического восстановления после аварийного завершения

```bash
# Имитация сбоя MariaDB
docker stop mariadb

# Перезапуск базы данных
docker start mariadb

# Проверка восстановления соединения WordPress с базой данных
sleep 15
curl -k https://wordpress.yourdomain.com
```

### 4.5.10. Тестирование оптимизации и кеширования

#### 4.5.10.1. Проверка оптимизации базы данных

```bash
# Оптимизация таблиц WordPress
docker exec mariadb mysqlcheck -u$MYSQL_USER -p$MYSQL_PASSWORD --optimize $MYSQL_DATABASE

# Анализ таблиц
docker exec mariadb mysqlcheck -u$MYSQL_USER -p$MYSQL_PASSWORD --analyze $MYSQL_DATABASE
```

#### 4.5.10.2. Проверка кеширования (если настроено)

```bash
# Проверка настроек кеширования в WordPress
docker exec wordpress wp config get WP_CACHE --path=/var/www/html

# Тестирование с включенным кешем
time curl -k -s https://wordpress.yourdomain.com > /dev/null
time curl -k -s https://wordpress.yourdomain.com > /dev/null  # Второй запрос должен быть быстрее

# Проверка использования Redis (если настроен)
docker exec redis redis-cli INFO | grep connected_clients
```

### 4.5.11. Мониторинг и журналирование

```bash
# Настройка и проверка журналирования ошибок в WordPress
docker exec wordpress grep WP_DEBUG /var/www/html/wp-config.php

# Временное включение отладки для тестирования
docker exec wordpress wp config set WP_DEBUG true --path=/var/www/html
docker exec wordpress wp config set WP_DEBUG_LOG true --path=/var/www/html
```

**Мониторинг производительности:**
```bash
# Мониторинг использования ресурсов контейнерами
docker stats wordpress mariadb

# Проверка размера базы данных
docker exec mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT table_schema, ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;"
```

## Рекомендации для эффективного тестирования WordPress и MariaDB

1. **Автоматизируйте регулярные проверки**: Создайте скрипты для автоматического тестирования основных функций.

2. **Используйте плагины для диагностики**: Установите плагины Query Monitor и WP Mail Log для отладки.

3. **Тестируйте на репрезентативных данных**: Заполните WordPress реалистичным контентом для точного тестирования.

4. **Применяйте многоуровневое тестирование**: Комбинируйте проверки на уровне HTTP, PHP и базы данных.

5. **Обеспечьте изоляцию тестов**: Используйте отдельное тестовое окружение для проверки обновлений.

6. **Внедрите мониторинг**: Настройте уведомления о критических проблемах сайта.

7. **Регулярно тестируйте резервное копирование**: Убедитесь, что процесс восстановления работает надежно.
