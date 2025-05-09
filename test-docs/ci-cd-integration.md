# Интеграция тестирования с CI/CD

## Введение

Данный документ описывает стратегию и технические аспекты интеграции тестирования стека с системами непрерывной интеграции и непрерывного развертывания (CI/CD). Автоматизация тестирования через CI/CD позволяет обеспечить регулярную проверку качества, стабильности и безопасности стека без необходимости ручного запуска.

## Поддерживаемые CI/CD платформы

Стратегии тестирования адаптированы для следующих CI/CD платформ:

1. **GitHub Actions** (основная)
2. **GitLab CI/CD**
3. **Jenkins**

## Структура файлов для CI/CD

### GitHub Actions

Файл конфигурации расположен в `.github/workflows/testing.yml`:

```yaml
name: NoCode Stack Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 0 * * 0'  # Еженедельный запуск (воскресенье в полночь)

jobs:
  tests:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up environment
      run: |
        cp .env.example .env
        # Заполнение переменных окружения для тестирования
        echo "DOMAIN_NAME=example.com" >> .env
        echo "POSTGRES_USER=postgres" >> .env
        echo "POSTGRES_PASSWORD=postgres_password" >> .env
        echo "POSTGRES_DB=postgres" >> .env
        echo "MYSQL_USER=mysql" >> .env
        echo "MYSQL_PASSWORD=mysql_password" >> .env
        echo "MYSQL_DATABASE=mysql" >> .env
    
    - name: Start Docker containers
      run: docker-compose up -d
    
    - name: Wait for services to be ready
      run: |
        sleep 30
        docker ps
    
    - name: Run dependency checks
      run: bash test-docs/run-all-tests.sh --check-dependencies
    
    - name: Run functional tests
      run: bash test-docs/run-all-tests.sh --functional
    
    - name: Run integration tests
      run: bash test-docs/run-all-tests.sh --integration
    
    - name: Run load tests
      run: bash test-docs/run-all-tests.sh --load
    
    - name: Run security tests
      run: bash test-docs/run-all-tests.sh --security
    
    - name: Generate test report
      if: always()
      run: bash test-docs/generate-test-report.sh
    
    - name: Upload test report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-report
        path: |
          test-reports/
          test-logs/
```

### GitLab CI/CD

Файл конфигурации расположен в `.gitlab-ci.yml`:

```yaml
image: docker:latest

services:
  - docker:dind

stages:
  - setup
  - test
  - report

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""

before_script:
  - cp .env.example .env
  - echo "DOMAIN_NAME=example.com" >> .env
  - echo "POSTGRES_USER=postgres" >> .env
  - echo "POSTGRES_PASSWORD=postgres_password" >> .env
  - echo "POSTGRES_DB=postgres" >> .env
  - echo "MYSQL_USER=mysql" >> .env
  - echo "MYSQL_PASSWORD=mysql_password" >> .env
  - echo "MYSQL_DATABASE=mysql" >> .env

setup_services:
  stage: setup
  script:
    - docker-compose up -d
    - sleep 30
    - docker ps
  artifacts:
    paths:
      - .env

dependency_checks:
  stage: test
  script:
    - bash test-docs/run-all-tests.sh --check-dependencies
  dependencies:
    - setup_services

functional_tests:
  stage: test
  script:
    - bash test-docs/run-all-tests.sh --functional
  dependencies:
    - setup_services
  artifacts:
    paths:
      - test-logs/functional/

integration_tests:
  stage: test
  script:
    - bash test-docs/run-all-tests.sh --integration
  dependencies:
    - setup_services
  artifacts:
    paths:
      - test-logs/integration/

load_tests:
  stage: test
  script:
    - bash test-docs/run-all-tests.sh --load
  dependencies:
    - setup_services
  artifacts:
    paths:
      - test-logs/load/

security_tests:
  stage: test
  script:
    - bash test-docs/run-all-tests.sh --security
  dependencies:
    - setup_services
  artifacts:
    paths:
      - test-logs/security/

generate_report:
  stage: report
  script:
    - bash test-docs/generate-test-report.sh
  dependencies:
    - functional_tests
    - integration_tests
    - load_tests
    - security_tests
  artifacts:
    paths:
      - test-reports/
    when: always
```

### Jenkins Pipeline

Файл конфигурации расположен в `Jenkinsfile`:

```groovy
pipeline {
    agent {
        docker {
            image 'docker:latest'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'cp .env.example .env'
                sh '''
                    echo "DOMAIN_NAME=example.com" >> .env
                    echo "POSTGRES_USER=postgres" >> .env
                    echo "POSTGRES_PASSWORD=postgres_password" >> .env
                    echo "POSTGRES_DB=postgres" >> .env
                    echo "MYSQL_USER=mysql" >> .env
                    echo "MYSQL_PASSWORD=mysql_password" >> .env
                    echo "MYSQL_DATABASE=mysql" >> .env
                '''
                sh 'docker-compose up -d'
                sh 'sleep 30'
                sh 'docker ps'
            }
        }
        
        stage('Dependency Checks') {
            steps {
                sh 'bash test-docs/run-all-tests.sh --check-dependencies'
            }
        }
        
        stage('Tests') {
            parallel {
                stage('Functional Tests') {
                    steps {
                        sh 'bash test-docs/run-all-tests.sh --functional'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'test-logs/functional/**', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Integration Tests') {
                    steps {
                        sh 'bash test-docs/run-all-tests.sh --integration'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'test-logs/integration/**', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Load Tests') {
                    steps {
                        sh 'bash test-docs/run-all-tests.sh --load'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'test-logs/load/**', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Security Tests') {
                    steps {
                        sh 'bash test-docs/run-all-tests.sh --security'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'test-logs/security/**', allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('Report') {
            steps {
                sh 'bash test-docs/generate-test-report.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'test-reports/**', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker-compose down -v'
        }
    }
}
```

## Модификация скриптов тестирования для CI/CD

Для корректной работы в среде CI/CD необходимо адаптировать существующие скрипты тестирования:

### Обновление скрипта run-all-tests.sh

Скрипт `run-all-tests.sh` должен быть модифицирован для поддержки параметров командной строки:

```bash
#!/bin/bash
# Скрипт для запуска всех тестов с поддержкой CI/CD
# Использование: run-all-tests.sh [--check-dependencies] [--functional] [--integration] [--load] [--security] [--all]

# Определение директорий для логов и отчетов
LOGS_DIR="$HOME/my-nocode-stack/test-logs"
REPORTS_DIR="$HOME/my-nocode-stack/test-reports"

# Создание директорий для логов и отчетов, если они не существуют
mkdir -p "$LOGS_DIR/functional"
mkdir -p "$LOGS_DIR/integration"
mkdir -p "$LOGS_DIR/load"
mkdir -p "$LOGS_DIR/security"
mkdir -p "$REPORTS_DIR"

# Функция для запуска функциональных тестов
run_functional_tests() {
    echo "Запуск функциональных тестов..."
    # Код для запуска функциональных тестов
    # ...
    
    # Запись результатов в лог-файл
    echo "Результаты функциональных тестов сохранены в $LOGS_DIR/functional/"
}

# Функция для запуска интеграционных тестов
run_integration_tests() {
    echo "Запуск интеграционных тестов..."
    # Код для запуска интеграционных тестов
    # ...
    
    # Запись результатов в лог-файл
    echo "Результаты интеграционных тестов сохранены в $LOGS_DIR/integration/"
}

# Функция для запуска нагрузочных тестов
run_load_tests() {
    echo "Запуск нагрузочных тестов..."
    # Код для запуска нагрузочных тестов
    # ...
    
    # Запись результатов в лог-файл
    echo "Результаты нагрузочных тестов сохранены в $LOGS_DIR/load/"
}

# Функция для запуска тестов безопасности
run_security_tests() {
    echo "Запуск тестов безопасности..."
    # Код для запуска тестов безопасности
    # ...
    
    # Запись результатов в лог-файл
    echo "Результаты тестов безопасности сохранены в $LOGS_DIR/security/"
}

# Проверка аргументов командной строки
if [[ $# -eq 0 ]]; then
    # Если аргументы не указаны, запустить все тесты
    run_functional_tests
    run_integration_tests
    run_load_tests
    run_security_tests
else
    # Иначе запустить только указанные тесты
    for arg in "$@"; do
        case $arg in
            --check-dependencies)
                # Код для проверки зависимостей
                echo "Проверка зависимостей..."
                ;;
            --functional)
                run_functional_tests
                ;;
            --integration)
                run_integration_tests
                ;;
            --load)
                run_load_tests
                ;;
            --security)
                run_security_tests
                ;;
            --all)
                run_functional_tests
                run_integration_tests
                run_load_tests
                run_security_tests
                ;;
            *)
                echo "Неизвестный аргумент: $arg"
                echo "Доступные аргументы: --check-dependencies, --functional, --integration, --load, --security, --all"
                exit 1
                ;;
        esac
    done
fi

echo "Все тесты завершены. Результаты сохранены в $LOGS_DIR/"
```

### Создание скрипта для генерации отчетов

Скрипт `generate-test-report.sh` для создания отчетов по результатам тестирования:

```bash
#!/bin/bash
# Скрипт для генерации отчетов по результатам тестирования

LOGS_DIR="$HOME/my-nocode-stack/test-logs"
REPORTS_DIR="$HOME/my-nocode-stack/test-reports"

# Создание директорий для отчетов, если они не существуют
mkdir -p "$REPORTS_DIR"

# Генерация HTML-отчета
generate_html_report() {
    REPORT_FILE="$REPORTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).html"
    
    # Создание заголовка отчета
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Отчет о тестировании NoCode Stack</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background-color: #f5f5f5; padding: 15px; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>Отчет о тестировании NoCode Stack</h1>
    <div class="summary">
        <h2>Сводка тестирования</h2>
        <p>Дата запуска: $(date +"%Y-%m-%d %H:%M:%S")</p>
EOF
    
    # Подсчет результатов тестов
    TOTAL_PASSED=$(grep -r "PASSED" "$LOGS_DIR" | wc -l)
    TOTAL_FAILED=$(grep -r "FAILED" "$LOGS_DIR" | wc -l)
    TOTAL_TESTS=$((TOTAL_PASSED + TOTAL_FAILED))
    
    # Добавление сводки результатов
    cat >> "$REPORT_FILE" << EOF
        <p>Всего тестов: $TOTAL_TESTS</p>
        <p>Пройдено: <span class="passed">$TOTAL_PASSED</span></p>
        <p>Не пройдено: <span class="failed">$TOTAL_FAILED</span></p>
        <p>Процент успешных: $(echo "scale=2; $TOTAL_PASSED * 100 / $TOTAL_TESTS" | bc)%</p>
    </div>
EOF
    
    # Добавление детальных результатов для каждого типа тестов
    for test_type in functional integration load security; do
        if [ -d "$LOGS_DIR/$test_type" ]; then
            # Подсчет результатов для данного типа тестов
            TYPE_PASSED=$(grep -r "PASSED" "$LOGS_DIR/$test_type" | wc -l)
            TYPE_FAILED=$(grep -r "FAILED" "$LOGS_DIR/$test_type" | wc -l)
            TYPE_TOTAL=$((TYPE_PASSED + TYPE_FAILED))
            
            # Добавление результатов для данного типа тестов
            cat >> "$REPORT_FILE" << EOF
    <h2>Результаты $(echo $test_type | tr '[:lower:]' '[:upper:]') тестов</h2>
    <p>Всего тестов: $TYPE_TOTAL</p>
    <p>Пройдено: <span class="passed">$TYPE_PASSED</span></p>
    <p>Не пройдено: <span class="failed">$TYPE_FAILED</span></p>
    <table>
        <tr>
            <th>Тест</th>
            <th>Результат</th>
            <th>Затраченное время</th>
        </tr>
EOF
            
            # Добавление результатов отдельных тестов
            for log_file in "$LOGS_DIR/$test_type"/*; do
                if [ -f "$log_file" ]; then
                    TEST_NAME=$(basename "$log_file" .log)
                    if grep -q "PASSED" "$log_file"; then
                        RESULT="<span class=\"passed\">PASSED</span>"
                    else
                        RESULT="<span class=\"failed\">FAILED</span>"
                    fi
                    TIME=$(grep "Time:" "$log_file" | awk '{print $2}' || echo "N/A")
                    
                    cat >> "$REPORT_FILE" << EOF
        <tr>
            <td>$TEST_NAME</td>
            <td>$RESULT</td>
            <td>$TIME</td>
        </tr>
EOF
                fi
            done
            
            cat >> "$REPORT_FILE" << EOF
    </table>
EOF
        fi
    done
    
    # Закрытие HTML-документа
    cat >> "$REPORT_FILE" << EOF
</body>
</html>
EOF
    
    echo "HTML-отчет создан: $REPORT_FILE"
}

# Генерация JSON-отчета для интеграции с CI/CD
generate_json_report() {
    REPORT_FILE="$REPORTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Инициализация JSON-структуры
    cat > "$REPORT_FILE" << EOF
{
    "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")",
    "summary": {
EOF
    
    # Подсчет результатов тестов
    TOTAL_PASSED=$(grep -r "PASSED" "$LOGS_DIR" | wc -l)
    TOTAL_FAILED=$(grep -r "FAILED" "$LOGS_DIR" | wc -l)
    TOTAL_TESTS=$((TOTAL_PASSED + TOTAL_FAILED))
    
    # Добавление сводки результатов
    cat >> "$REPORT_FILE" << EOF
        "total": $TOTAL_TESTS,
        "passed": $TOTAL_PASSED,
        "failed": $TOTAL_FAILED,
        "successRate": $(echo "scale=2; $TOTAL_PASSED * 100 / $TOTAL_TESTS" | bc)
    },
    "testTypes": {
EOF
    
    # Добавление детальных результатов для каждого типа тестов
    FIRST_TYPE=true
    for test_type in functional integration load security; do
        if [ -d "$LOGS_DIR/$test_type" ]; then
            if [ "$FIRST_TYPE" = true ]; then
                FIRST_TYPE=false
            else
                echo "        }," >> "$REPORT_FILE"
            fi
            
            # Подсчет результатов для данного типа тестов
            TYPE_PASSED=$(grep -r "PASSED" "$LOGS_DIR/$test_type" | wc -l)
            TYPE_FAILED=$(grep -r "FAILED" "$LOGS_DIR/$test_type" | wc -l)
            TYPE_TOTAL=$((TYPE_PASSED + TYPE_FAILED))
            
            # Добавление результатов для данного типа тестов
            cat >> "$REPORT_FILE" << EOF
        "$test_type": {
            "total": $TYPE_TOTAL,
            "passed": $TYPE_PASSED,
            "failed": $TYPE_FAILED,
            "tests": [
EOF
            
            # Добавление результатов отдельных тестов
            FIRST_TEST=true
            for log_file in "$LOGS_DIR/$test_type"/*; do
                if [ -f "$log_file" ]; then
                    if [ "$FIRST_TEST" = true ]; then
                        FIRST_TEST=false
                    else
                        echo "                }," >> "$REPORT_FILE"
                    fi
                    
                    TEST_NAME=$(basename "$log_file" .log)
                    if grep -q "PASSED" "$log_file"; then
                        RESULT="PASSED"
                    else
                        RESULT="FAILED"
                    fi
                    TIME=$(grep "Time:" "$log_file" | awk '{print $2}' || echo "N/A")
                    
                    cat >> "$REPORT_FILE" << EOF
                {
                    "name": "$TEST_NAME",
                    "result": "$RESULT",
                    "time": "$TIME"
EOF
                fi
            done
            
            if [ "$FIRST_TEST" = false ]; then
                echo "                }" >> "$REPORT_FILE"
            fi
            
            cat >> "$REPORT_FILE" << EOF
            ]
EOF
        fi
    done
    
    if [ "$FIRST_TYPE" = false ]; then
        echo "        }" >> "$REPORT_FILE"
    fi
    
    # Закрытие JSON-структуры
    cat >> "$REPORT_FILE" << EOF
    }
}
EOF
    
    echo "JSON-отчет создан: $REPORT_FILE"
}

# Генерация отчетов
generate_html_report
generate_json_report

echo "Все отчеты созданы в директории $REPORTS_DIR/"
```

## Инструкция по настройке CI/CD

### Настройка GitHub Actions

1. Создайте директорию `.github/workflows` в корне репозитория
2. Скопируйте файл `testing.yml` в эту директорию
3. Настройте секреты репозитория для хранения чувствительных данных

### Настройка GitLab CI/CD

1. Скопируйте файл `.gitlab-ci.yml` в корень репозитория
2. Настройте переменные CI/CD в настройках проекта
3. Добавьте Docker runner в GitLab

### Настройка Jenkins

1. Скопируйте файл `Jenkinsfile` в корень репозитория
2. Создайте Pipeline job в Jenkins, указав путь к репозиторию
3. Настройте credentials в Jenkins для доступа к репозиторию

## Рекомендации по использованию CI/CD

1. **Регулярное тестирование**: настройте еженедельное автоматическое тестирование
2. **Тестирование при изменениях**: запускайте тесты при каждом push в основные ветки
3. **Секционное тестирование**: при малых изменениях используйте соответствующие типы тестов
4. **Анализ результатов**: настройте оповещения о результатах тестирования

## Метрики и мониторинг CI/CD

Для эффективного мониторинга процесса CI/CD рекомендуется отслеживать следующие метрики:

1. **Время выполнения тестов**: отслеживание общего времени и времени выполнения отдельных типов тестов
2. **Процент успешных тестов**: отслеживание динамики успешного прохождения тестов
3. **Частота запуска тестов**: анализ регулярности тестирования
4. **Покрытие кода**: анализ покрытия кода тестами (если применимо)

## Заключение

Интеграция с CI/CD системами позволяет автоматизировать процесс тестирования и обеспечить регулярную проверку качества стека. Созданные конфигурационные файлы и скрипты могут быть адаптированы для различных CI/CD платформ и разных сценариев использования.
