#!/bin/bash
# Скрипт для генерации отчетов по результатам тестирования

LOGS_DIR="$HOME/my-nocode-stack/test-logs"
REPORTS_DIR="$HOME/my-nocode-stack/test-reports"

# Создание директорий для отчетов, если они не существуют
mkdir -p "$REPORTS_DIR"

# Определение цветов для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo -e "${GREEN}Генерация отчетов по результатам тестирования...${RESET}"

# Генерация HTML-отчета
generate_html_report() {
    REPORT_FILE="$REPORTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).html"
    
    # Создание заголовка отчета
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Отчет о тестировании NoCode Stack</title>
    <meta charset="UTF-8">
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
    TOTAL_PASSED=$(grep -r "PASSED" "$LOGS_DIR" 2>/dev/null | wc -l)
    TOTAL_FAILED=$(grep -r "FAILED" "$LOGS_DIR" 2>/dev/null | wc -l)
    TOTAL_TESTS=$((TOTAL_PASSED + TOTAL_FAILED))
    
    # Защита от деления на ноль
    if [ $TOTAL_TESTS -eq 0 ]; then
        SUCCESS_RATE="0.00"
    else
        SUCCESS_RATE=$(echo "scale=2; $TOTAL_PASSED * 100 / $TOTAL_TESTS" | bc)
    fi
    
    # Добавление сводки результатов
    cat >> "$REPORT_FILE" << EOF
        <p>Всего тестов: $TOTAL_TESTS</p>
        <p>Пройдено: <span class="passed">$TOTAL_PASSED</span></p>
        <p>Не пройдено: <span class="failed">$TOTAL_FAILED</span></p>
        <p>Процент успешных: ${SUCCESS_RATE}%</p>
    </div>
EOF
    
    # Добавление детальных результатов для каждого типа тестов
    for test_type in functional integration load security; do
        if [ -d "$LOGS_DIR/$test_type" ]; then
            # Подсчет результатов для данного типа тестов
            TYPE_PASSED=$(grep -r "PASSED" "$LOGS_DIR/$test_type" 2>/dev/null | wc -l)
            TYPE_FAILED=$(grep -r "FAILED" "$LOGS_DIR/$test_type" 2>/dev/null | wc -l)
            TYPE_TOTAL=$((TYPE_PASSED + TYPE_FAILED))
            
            # Защита от пустой директории
            if [ $TYPE_TOTAL -eq 0 ]; then
                continue
            fi
            
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
    
    echo -e "${GREEN}HTML-отчет создан:${RESET} $REPORT_FILE"
}

# Генерация JSON-отчета для интеграции с CI/CD
generate_json_report() {
    REPORT_FILE="$REPORTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Подсчет результатов тестов
    TOTAL_PASSED=$(grep -r "PASSED" "$LOGS_DIR" 2>/dev/null | wc -l)
    TOTAL_FAILED=$(grep -r "FAILED" "$LOGS_DIR" 2>/dev/null | wc -l)
    TOTAL_TESTS=$((TOTAL_PASSED + TOTAL_FAILED))
    
    # Защита от деления на ноль
    if [ $TOTAL_TESTS -eq 0 ]; then
        SUCCESS_RATE="0.00"
    else
        SUCCESS_RATE=$(echo "scale=2; $TOTAL_PASSED * 100 / $TOTAL_TESTS" | bc)
    fi
    
    # Инициализация JSON-структуры
    cat > "$REPORT_FILE" << EOF
{
    "timestamp": "$(date +"%Y-%m-%d %H:%M:%S")",
    "summary": {
        "total": $TOTAL_TESTS,
        "passed": $TOTAL_PASSED,
        "failed": $TOTAL_FAILED,
        "successRate": $SUCCESS_RATE
    },
    "testTypes": {
EOF
    
    # Добавление детальных результатов для каждого типа тестов
    FIRST_TYPE=true
    for test_type in functional integration load security; do
        if [ -d "$LOGS_DIR/$test_type" ]; then
            # Подсчет результатов для данного типа тестов
            TYPE_PASSED=$(grep -r "PASSED" "$LOGS_DIR/$test_type" 2>/dev/null | wc -l)
            TYPE_FAILED=$(grep -r "FAILED" "$LOGS_DIR/$test_type" 2>/dev/null | wc -l)
            TYPE_TOTAL=$((TYPE_PASSED + TYPE_FAILED))
            
            # Защита от пустой директории
            if [ $TYPE_TOTAL -eq 0 ]; then
                continue
            fi
            
            if [ "$FIRST_TYPE" = true ]; then
                FIRST_TYPE=false
            else
                echo "        }," >> "$REPORT_FILE"
            fi
            
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
    
    echo -e "${GREEN}JSON-отчет создан:${RESET} $REPORT_FILE"
}

# Создание директорий для логов, если их нет
mkdir -p "$LOGS_DIR/functional"
mkdir -p "$LOGS_DIR/integration"
mkdir -p "$LOGS_DIR/load"
mkdir -p "$LOGS_DIR/security"

# Если директория logs не содержит логов, создаем тестовые логи для демонстрации
if [ $(find "$LOGS_DIR" -type f | wc -l) -eq 0 ]; then
    echo -e "${YELLOW}Не найдены логи тестирования. Создание демонстрационных логов...${RESET}"
    
    # Создание демонстрационных логов функциональных тестов
    echo "Test: wordpress_availability\nResult: PASSED\nTime: 2.5s" > "$LOGS_DIR/functional/wordpress_availability.log"
    echo "Test: postgres_connection\nResult: PASSED\nTime: 1.2s" > "$LOGS_DIR/functional/postgres_connection.log"
    echo "Test: n8n_api\nResult: FAILED\nTime: 3.1s" > "$LOGS_DIR/functional/n8n_api.log"
    
    # Создание демонстрационных логов интеграционных тестов
    echo "Test: wordpress_postgres\nResult: PASSED\nTime: 4.3s" > "$LOGS_DIR/integration/wordpress_postgres.log"
    echo "Test: n8n_flowise\nResult: PASSED\nTime: 5.0s" > "$LOGS_DIR/integration/n8n_flowise.log"
    
    # Создание демонстрационных логов нагрузочных тестов
    echo "Test: wordpress_load\nResult: PASSED\nTime: 15.7s" > "$LOGS_DIR/load/wordpress_load.log"
    echo "Test: db_load\nResult: FAILED\nTime: 12.3s" > "$LOGS_DIR/load/db_load.log"
    
    # Создание демонстрационных логов тестов безопасности
    echo "Test: vulnerability_scan\nResult: PASSED\nTime: 8.2s" > "$LOGS_DIR/security/vulnerability_scan.log"
    echo "Test: port_scan\nResult: PASSED\nTime: 6.5s" > "$LOGS_DIR/security/port_scan.log"
fi

# Генерация отчетов
generate_html_report
generate_json_report

echo -e "${GREEN}Все отчеты созданы в директории:${RESET} $REPORTS_DIR"

# Делаем скрипт исполняемым
chmod +x $0
