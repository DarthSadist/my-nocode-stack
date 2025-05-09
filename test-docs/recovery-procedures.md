# Руководство по восстановлению после сбоев тестирования

## Введение

Данное руководство содержит инструкции по восстановлению системы после сбоев, которые могут возникнуть в процессе тестирования. Соблюдение этих процедур позволит быстро восстановить работоспособность стека и продолжить тестирование без потери данных.

## Содержание

1. [Восстановление после сбоев контейнеров](#1-восстановление-после-сбоев-контейнеров)
2. [Восстановление после сбоев баз данных](#2-восстановление-после-сбоев-баз-данных)
3. [Восстановление после сетевых сбоев](#3-восстановление-после-сетевых-сбоев)
4. [Восстановление после сбоев в процессе нагрузочного тестирования](#4-восстановление-после-сбоев-в-процессе-нагрузочного-тестирования)
5. [Восстановление после сбоев в процессе тестирования безопасности](#5-восстановление-после-сбоев-в-процессе-тестирования-безопасности)

## 1. Восстановление после сбоев контейнеров

### 1.1. Диагностика сбойных контейнеров

```bash
# Проверка состояния всех контейнеров
docker ps -a

# Проверка логов сбойного контейнера
docker logs [имя_контейнера]

# Проверка использования ресурсов
docker stats --no-stream
```

### 1.2. Перезапуск отдельных контейнеров

```bash
# Перезапуск определенного контейнера
docker restart [имя_контейнера]

# Перезапуск с удалением и пересозданием контейнера
docker-compose up -d --force-recreate [имя_сервиса]
```

### 1.3. Восстановление всего стека

```bash
# Полная остановка стека
docker-compose down

# Удаление проблемных томов (при необходимости)
docker volume rm [имя_тома]

# Запуск стека с пересозданием контейнеров
docker-compose up -d --force-recreate
```

## 2. Восстановление после сбоев баз данных

### 2.1. PostgreSQL

```bash
# Проверка состояния PostgreSQL
docker exec postgres pg_isready

# Перезапуск PostgreSQL без потери данных
docker restart postgres

# Восстановление из резервной копии (если существует)
docker exec postgres pg_restore -U $POSTGRES_USER -d [имя_бд] /path/to/backup.dump
```

### 2.2. MariaDB

```bash
# Проверка состояния MariaDB
docker exec mariadb mysqladmin -u$MYSQL_USER -p$MYSQL_PASSWORD ping

# Проверка целостности таблиц
docker exec mariadb mysqlcheck -u$MYSQL_USER -p$MYSQL_PASSWORD --check --all-databases

# Восстановление из резервной копии
docker exec -i mariadb mysql -u$MYSQL_USER -p$MYSQL_PASSWORD [имя_бд] < /path/to/backup.sql
```

### 2.3. Redis

```bash
# Проверка состояния Redis
docker exec redis redis-cli ping

# Сброс данных Redis (только если необходимо!)
docker exec redis redis-cli FLUSHALL

# Перезагрузка конфигурации Redis
docker exec redis redis-cli CONFIG REWRITE
```

## 3. Восстановление после сетевых сбоев

### 3.1. Диагностика сетевых проблем

```bash
# Проверка сетевых настроек Docker
docker network ls
docker network inspect [имя_сети]

# Проверка доступности сервисов
for service in n8n flowise wordpress qdrant; do
  docker exec -it postgres ping -c 1 $service
done
```

### 3.2. Восстановление сети Docker

```bash
# Перезапуск сетей Docker
docker-compose down
docker network prune -f
docker-compose up -d
```

### 3.3. Решение проблем с DNS

```bash
# Очистка DNS-кэша Docker
docker exec -it postgres bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
```

## 4. Восстановление после сбоев в процессе нагрузочного тестирования

### 4.1. Остановка процессов нагрузочного тестирования

```bash
# Поиск процессов нагрузочного тестирования
ps aux | grep -E "ab|siege|stress|load_test"

# Остановка процессов
kill -9 [PID_процесса]
```

### 4.2. Очистка временных файлов

```bash
# Очистка временных файлов тестирования
find ~/my-nocode-stack/test-scripts -name "load-test-*.log" -mtime +7 -delete
```

### 4.3. Перезапуск системы мониторинга

```bash
# Перезапуск Netdata для восстановления мониторинга
docker restart netdata
```

## 5. Восстановление после сбоев в процессе тестирования безопасности

### 5.1. Восстановление после сканирования уязвимостей

```bash
# Проверка и остановка активных сканирований
ps aux | grep -E "nmap|nikto|trivy"
kill -9 [PID_процесса]

# Восстановление правил брандмауэра (если были изменения)
docker exec [контейнер] iptables-restore < /path/to/backup/rules
```

### 5.2. Восстановление доступа к сервисам

```bash
# Сброс настроек безопасности в случае блокировки
docker exec postgres psql -U $POSTGRES_USER -c "ALTER ROLE $POSTGRES_USER WITH LOGIN;"
docker exec mariadb mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%';"
```

### 5.3. Очистка логов после тестирования

```bash
# Очистка логов после тестирования безопасности
for container in postgres mariadb n8n flowise; do
  docker exec $container bash -c "echo '' > /var/log/*.log"
done
```

## Общие рекомендации

1. **Всегда делайте резервные копии** перед началом интенсивного тестирования
2. **Документируйте изменения** в конфигурации во время тестирования
3. **Используйте отдельные среды** для тестирования и продакшн, когда это возможно
4. **Сохраняйте версии команд** в истории терминала для быстрого восстановления
5. **Ведите лог инцидентов** с описанием проблем и методов их решения

## Контрольный список восстановления

- [ ] Проверить логи контейнеров для выявления причин сбоя
- [ ] Перезапустить отдельные компоненты, начиная с баз данных
- [ ] Проверить сетевую связность между компонентами
- [ ] Проверить доступность внешних API и сервисов
- [ ] Проверить целостность данных после восстановления
- [ ] Запустить базовые тесты для подтверждения работоспособности

## Автоматическое восстановление

Для автоматизации восстановления можно использовать следующий скрипт:

```bash
#!/bin/bash
# Скрипт автоматического восстановления
# Сохраните как ~/my-nocode-stack/test-scripts/auto-recovery.sh

echo "Начало процедуры восстановления..."

# Диагностика состояния
echo "Проверка состояния контейнеров..."
docker ps -a

# Перезапуск сбойных контейнеров
for container in postgres redis mariadb n8n flowise wordpress qdrant; do
  if ! docker ps | grep -q $container; then
    echo "Перезапуск контейнера $container..."
    docker start $container || docker-compose up -d $container
  fi
done

# Проверка баз данных
echo "Проверка состояния баз данных..."
docker exec postgres pg_isready || docker restart postgres
docker exec mariadb mysqladmin -u$MYSQL_USER -p$MYSQL_PASSWORD ping || docker restart mariadb
docker exec redis redis-cli ping || docker restart redis

# Проверка сетевой связности
echo "Проверка сетевой связности..."
for service in n8n flowise wordpress qdrant; do
  docker exec postgres ping -c 1 $service || echo "Проблема связности с $service"
done

echo "Восстановление завершено. Проверьте логи на наличие ошибок."
```

Сделайте скрипт исполняемым:

```bash
chmod +x ~/my-nocode-stack/test-scripts/auto-recovery.sh
```

Этот скрипт можно запустить при обнаружении проблем в работе стека в процессе тестирования.
