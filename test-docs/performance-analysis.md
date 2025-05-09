# Анализ производительности системы

## Введение

Данный документ описывает методологию, инструменты и метрики для комплексного анализа производительности компонентов NoCode Stack. Целью анализа является выявление узких мест, оптимизация ресурсов и обеспечение стабильной работы системы под различными нагрузками.

## Методология анализа производительности

### Комплексный подход к анализу

Анализ производительности осуществляется на следующих уровнях:

1. **Уровень инфраструктуры**
   - Мониторинг потребления ресурсов хост-системы
   - Анализ производительности Docker и контейнеров
   - Оценка сетевого взаимодействия между компонентами

2. **Уровень приложений**
   - Анализ времени отклика сервисов
   - Оценка производительности баз данных
   - Анализ пропускной способности API

3. **Уровень пользовательского взаимодействия**
   - Оценка скорости загрузки интерфейсов
   - Анализ времени выполнения типичных пользовательских сценариев
   - Исследование удовлетворенности пользователей (UX)

## Инструменты для анализа производительности

### Мониторинг системы

- **Netdata** - мониторинг системных ресурсов в режиме реального времени
- **Prometheus + Grafana** - сбор и визуализация метрик
- **cAdvisor** - мониторинг контейнеров Docker

### Анализ сетевого взаимодействия

- **tcpdump** - анализ сетевого трафика
- **Wireshark** - детальный анализ пакетов
- **iptraf** - мониторинг сетевых интерфейсов

### Нагрузочное тестирование

- **Apache Benchmark (ab)** - тестирование HTTP-сервисов
- **Siege** - нагрузочное тестирование веб-серверов
- **wrk** - высокопроизводительное нагрузочное тестирование

### Профилирование баз данных

- **pg_stat_statements** - анализ запросов PostgreSQL
- **EXPLAIN ANALYZE** - анализ плана запросов
- **mysqltuner** - анализ производительности MySQL/MariaDB

### Анализ пользовательского интерфейса

- **Lighthouse** - анализ скорости загрузки веб-страниц
- **WebPageTest** - комплексный анализ производительности веб-страниц
- **Browser Developer Tools** - анализ времени загрузки компонентов

## Метрики производительности

### Системные метрики

| Метрика | Описание | Целевое значение | Критическое значение |
|---------|----------|------------------|---------------------|
| CPU Usage | Использование процессора | <70% | >90% |
| Memory Usage | Использование памяти | <80% | >95% |
| Disk I/O | Операции чтения/записи на диск | <5000 IOPS | >10000 IOPS |
| Network Bandwidth | Использование пропускной способности сети | <70% | >90% |
| Container Restarts | Количество перезапусков контейнеров | 0 за 24 часа | >3 за 24 часа |

### Метрики приложений

| Метрика | Описание | Целевое значение | Критическое значение |
|---------|----------|------------------|---------------------|
| Response Time | Время отклика API | <200ms | >1000ms |
| Throughput | Пропускная способность (запросов в секунду) | >100 RPS | <50 RPS |
| Error Rate | Процент ошибок | <0.1% | >1% |
| Database Query Time | Время выполнения запросов к БД | <50ms | >200ms |
| Connection Pool Usage | Использование пула соединений | <70% | >90% |

### Пользовательские метрики

| Метрика | Описание | Целевое значение | Критическое значение |
|---------|----------|------------------|---------------------|
| Page Load Time | Время загрузки страницы | <2с | >5с |
| Time to First Byte | Время до первого байта | <200ms | >500ms |
| First Contentful Paint | Первое отображение контента | <1с | >3с |
| Time to Interactive | Время до интерактивности | <3с | >7с |
| User Satisfaction Score | Оценка удовлетворенности пользователей | >4.5/5 | <3.5/5 |

## Процедуры анализа производительности

### Базовый мониторинг системы

```bash
#!/bin/bash
# Скрипт мониторинга базовых метрик системы
# Сохраните как ~/my-nocode-stack/test-scripts/monitor-system.sh

OUTPUT_FILE="$HOME/my-nocode-stack/test-logs/system_metrics_$(date +%Y%m%d_%H%M%S).log"

echo "Время запуска: $(date)" > $OUTPUT_FILE
echo "=== Использование CPU ===" >> $OUTPUT_FILE
top -bn1 | head -20 >> $OUTPUT_FILE

echo -e "\n=== Использование памяти ===" >> $OUTPUT_FILE
free -m >> $OUTPUT_FILE

echo -e "\n=== Дисковое пространство ===" >> $OUTPUT_FILE
df -h >> $OUTPUT_FILE

echo -e "\n=== Статистика сети ===" >> $OUTPUT_FILE
netstat -tulpn | grep LISTEN >> $OUTPUT_FILE

echo -e "\n=== Статистика Docker ===" >> $OUTPUT_FILE
docker stats --no-stream >> $OUTPUT_FILE

echo -e "\n=== Логи контейнеров (последние 10 строк) ===" >> $OUTPUT_FILE
for container in $(docker ps -q); do
  echo -e "\nКонтейнер: $(docker inspect --format '{{.Name}}' $container)" >> $OUTPUT_FILE
  docker logs --tail 10 $container 2>&1 >> $OUTPUT_FILE
done

echo "Отчет сохранен в $OUTPUT_FILE"
```

### Анализ производительности PostgreSQL

```bash
#!/bin/bash
# Скрипт анализа производительности PostgreSQL
# Сохраните как ~/my-nocode-stack/test-scripts/analyze-postgres.sh

OUTPUT_FILE="$HOME/my-nocode-stack/test-logs/postgres_performance_$(date +%Y%m%d_%H%M%S).log"

echo "Время запуска: $(date)" > $OUTPUT_FILE

echo -e "\n=== Активные соединения ===" >> $OUTPUT_FILE
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT count(*) FROM pg_stat_activity;" >> $OUTPUT_FILE

echo -e "\n=== Статистика по таблицам ===" >> $OUTPUT_FILE
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT schemaname, relname, n_live_tup, n_dead_tup, last_autovacuum FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 10;" >> $OUTPUT_FILE

echo -e "\n=== Длительные запросы ===" >> $OUTPUT_FILE
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT pid, now() - query_start AS duration, state, query FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC LIMIT 10;" >> $OUTPUT_FILE

echo -e "\n=== Статистика индексов ===" >> $OUTPUT_FILE
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch FROM pg_stat_user_indexes ORDER BY idx_scan DESC LIMIT 10;" >> $OUTPUT_FILE

echo -e "\n=== Вакуум и анализ ===" >> $OUTPUT_FILE
docker exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT schemaname, relname, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze FROM pg_stat_user_tables;" >> $OUTPUT_FILE

echo "Отчет сохранен в $OUTPUT_FILE"
```

### Нагрузочное тестирование веб-интерфейсов

```bash
#!/bin/bash
# Скрипт нагрузочного тестирования веб-интерфейсов
# Сохраните как ~/my-nocode-stack/test-scripts/load-test-web.sh

OUTPUT_DIR="$HOME/my-nocode-stack/test-logs/load"
mkdir -p $OUTPUT_DIR

# Загрузка переменных окружения
source $HOME/my-nocode-stack/.env

# Функция для проведения нагрузочного тестирования
run_load_test() {
  SERVICE=$1
  URL=$2
  CONCURRENCY=$3
  REQUESTS=$4
  
  echo "Тестирование сервиса $SERVICE..."
  OUTPUT_FILE="$OUTPUT_DIR/${SERVICE}_load_$(date +%Y%m%d_%H%M%S).log"
  
  echo "Время запуска: $(date)" > $OUTPUT_FILE
  echo "Сервис: $SERVICE" >> $OUTPUT_FILE
  echo "URL: $URL" >> $OUTPUT_FILE
  echo "Параллельных запросов: $CONCURRENCY" >> $OUTPUT_FILE
  echo "Всего запросов: $REQUESTS" >> $OUTPUT_FILE
  echo -e "\n=== Результаты тестирования ===" >> $OUTPUT_FILE
  
  # Проверка доступности URL
  if curl -s --head $URL | grep "200 OK" > /dev/null; then
    ab -c $CONCURRENCY -n $REQUESTS -g "$OUTPUT_DIR/${SERVICE}_gnuplot.tsv" $URL >> $OUTPUT_FILE 2>&1
    echo -e "\nТестирование завершено. Результаты сохранены в $OUTPUT_FILE"
  else
    echo "Ошибка: URL $URL недоступен" | tee -a $OUTPUT_FILE
  fi
}

# Проведение тестирования для разных сервисов
run_load_test "wordpress" "http://$DOMAIN_NAME" 10 1000
run_load_test "n8n" "http://n8n.$DOMAIN_NAME" 10 500
run_load_test "flowise" "http://flowise.$DOMAIN_NAME" 10 500
run_load_test "qdrant" "http://qdrant.$DOMAIN_NAME" 5 200

echo "Все тесты завершены. Результаты сохранены в директории $OUTPUT_DIR"
```

### Анализ времени загрузки страниц

```bash
#!/bin/bash
# Скрипт анализа времени загрузки страниц
# Сохраните как ~/my-nocode-stack/test-scripts/analyze-page-load.sh

OUTPUT_DIR="$HOME/my-nocode-stack/test-logs/performance"
mkdir -p $OUTPUT_DIR

# Загрузка переменных окружения
source $HOME/my-nocode-stack/.env

# Функция для проведения анализа времени загрузки
analyze_page_load() {
  SERVICE=$1
  URL=$2
  
  echo "Анализ времени загрузки для сервиса $SERVICE..."
  OUTPUT_FILE="$OUTPUT_DIR/${SERVICE}_pageload_$(date +%Y%m%d_%H%M%S).log"
  
  echo "Время запуска: $(date)" > $OUTPUT_FILE
  echo "Сервис: $SERVICE" >> $OUTPUT_FILE
  echo "URL: $URL" >> $OUTPUT_FILE
  echo -e "\n=== Результаты анализа ===" >> $OUTPUT_FILE
  
  # Проверка доступности URL
  if curl -s --head $URL | grep "200 OK" > /dev/null; then
    # Использование curl для измерения времени
    curl -s -w "\nВремя подключения: %{time_connect}s\nВремя до первого байта: %{time_starttransfer}s\nОбщее время: %{time_total}s\n" -o /dev/null $URL >> $OUTPUT_FILE
    
    echo -e "\nАнализ завершен. Результаты сохранены в $OUTPUT_FILE"
  else
    echo "Ошибка: URL $URL недоступен" | tee -a $OUTPUT_FILE
  fi
}

# Проведение анализа для разных сервисов
analyze_page_load "wordpress_home" "http://$DOMAIN_NAME"
analyze_page_load "wordpress_admin" "http://$DOMAIN_NAME/wp-admin"
analyze_page_load "n8n" "http://n8n.$DOMAIN_NAME"
analyze_page_load "flowise" "http://flowise.$DOMAIN_NAME"
analyze_page_load "qdrant" "http://qdrant.$DOMAIN_NAME"

echo "Все анализы завершены. Результаты сохранены в директории $OUTPUT_DIR"
```

## Рекомендации по оптимизации производительности

### Оптимизация Docker

1. **Использование кэширования томов**
   ```bash
   docker run --volume-driver=local --volumes-from data-container your-image
   ```

2. **Оптимизация настроек логирования**
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   ```

3. **Ограничение ресурсов контейнеров**
   ```yaml
   services:
     wordpress:
       image: wordpress
       deploy:
         resources:
           limits:
             cpus: '0.50'
             memory: 512M
           reservations:
             cpus: '0.25'
             memory: 256M
   ```

### Оптимизация PostgreSQL

1. **Настройка memory settings**
   ```
   shared_buffers = 256MB
   effective_cache_size = 768MB
   maintenance_work_mem = 64MB
   work_mem = 4MB
   ```

2. **Оптимизация подсистемы хранения**
   ```
   wal_buffers = 16MB
   checkpoint_completion_target = 0.9
   random_page_cost = 4.0
   ```

3. **Настройка autovacuum**
   ```
   autovacuum = on
   autovacuum_max_workers = 3
   autovacuum_naptime = 1min
   ```

### Оптимизация веб-серверов

1. **Включение сжатия**
   ```
   gzip on;
   gzip_comp_level 5;
   gzip_min_length 256;
   gzip_proxied any;
   gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
   ```

2. **Настройка кэширования браузера**
   ```
   location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
       expires 30d;
       add_header Cache-Control "public, no-transform";
   }
   ```

3. **Настройка буферизации**
   ```
   proxy_buffers 16 32k;
   proxy_buffer_size 64k;
   ```

## План оптимизации производительности

### Краткосрочные меры (1-2 дня)

1. Настройка основных параметров баз данных
2. Оптимизация настроек логирования контейнеров
3. Настройка кэширования статических файлов в веб-серверах

### Среднесрочные меры (1-2 недели)

1. Внедрение мониторинга производительности (Prometheus + Grafana)
2. Профилирование запросов к базам данных
3. Оптимизация SQL-запросов и индексов

### Долгосрочные меры (1-3 месяца)

1. Разработка стратегии горизонтального масштабирования
2. Внедрение CDN для статического контента
3. Реорганизация архитектуры для повышения производительности

## Заключение

Комплексный анализ производительности позволяет выявить узкие места в системе и принять обоснованные решения по оптимизации. Регулярное проведение описанных процедур анализа обеспечит стабильную работу стека даже при увеличении нагрузки.

## Приложения

### Шаблон отчета о производительности

```
# Отчет о производительности NoCode Stack

## Общая информация
Дата: [Дата]
Версия стека: [Версия]
Тип окружения: [Разработка/Тестирование/Продакшн]

## Сводка результатов
Общая оценка производительности: [Отлично/Хорошо/Удовлетворительно/Требует улучшения]

## Системные метрики
- CPU Usage: [Значение]
- Memory Usage: [Значение]
- Disk I/O: [Значение]
- Network Bandwidth: [Значение]

## Метрики приложений
- Среднее время отклика: [Значение]
- Пропускная способность: [Значение]
- Уровень ошибок: [Значение]

## Пользовательские метрики
- Среднее время загрузки страницы: [Значение]
- Time to First Byte: [Значение]
- First Contentful Paint: [Значение]

## Выявленные проблемы
1. [Проблема 1]
2. [Проблема 2]
3. [Проблема 3]

## Рекомендации
1. [Рекомендация 1]
2. [Рекомендация 2]
3. [Рекомендация 3]

## Следующие шаги
1. [Шаг 1]
2. [Шаг 2]
3. [Шаг 3]
```

### Список рекомендуемых инструментов мониторинга

- Netdata: https://www.netdata.cloud/
- Prometheus: https://prometheus.io/
- Grafana: https://grafana.com/
- pgBadger: https://github.com/darold/pgbadger
- MySQLTuner: https://github.com/major/MySQLTuner-perl
- Siege: https://github.com/JoeDog/siege
- ab (Apache Benchmark): https://httpd.apache.org/docs/2.4/programs/ab.html
- Lighthouse: https://developers.google.com/web/tools/lighthouse
