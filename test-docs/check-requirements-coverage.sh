#!/bin/bash
# Скрипт для проверки покрытия требований тестами
# Сохраните как ~/my-nocode-stack/test-docs/check-requirements-coverage.sh

MATRIX_FILE="$HOME/my-nocode-stack/test-docs/requirements-traceability-matrix.md"
REPORT_FILE="$HOME/my-nocode-stack/test-docs/requirements-coverage-report.md"

# Определение цветов для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo "Проверка покрытия требований тестами..."

# Подсчет требований и их покрытия
TOTAL_REQ=$(grep -E "^| FR-|^| NFR-" "$MATRIX_FILE" | wc -l)
FULL_COVERAGE=$(grep -E "Полное" "$MATRIX_FILE" | wc -l)
PARTIAL_COVERAGE=$(grep -E "Частичное" "$MATRIX_FILE" | wc -l)
NO_COVERAGE=$(grep -E "Не покрыто" "$MATRIX_FILE" | wc -l)

# Расчет процентов покрытия
FULL_PERCENT=$(echo "scale=2; $FULL_COVERAGE * 100 / $TOTAL_REQ" | bc)
PARTIAL_PERCENT=$(echo "scale=2; $PARTIAL_COVERAGE * 100 / $TOTAL_REQ" | bc)
NO_PERCENT=$(echo "scale=2; $NO_COVERAGE * 100 / $TOTAL_REQ" | bc)

# Вывод статистики
echo -e "${GREEN}Статистика покрытия требований:${RESET}"
echo -e "Всего требований: $TOTAL_REQ"
echo -e "Полное покрытие: $FULL_COVERAGE ($FULL_PERCENT%)"
echo -e "Частичное покрытие: $PARTIAL_COVERAGE ($PARTIAL_PERCENT%)"
echo -e "Не покрыто: $NO_COVERAGE ($NO_PERCENT%)"

# Создание отчета
echo "# Отчет о покрытии требований тестами" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "## Сводная статистика" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Дата создания отчета:** $(date +'%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Метрика | Количество | Процент |" >> "$REPORT_FILE"
echo "|---------|------------|---------|" >> "$REPORT_FILE"
echo "| Всего требований | $TOTAL_REQ | 100% |" >> "$REPORT_FILE"
echo "| Полное покрытие | $FULL_COVERAGE | $FULL_PERCENT% |" >> "$REPORT_FILE"
echo "| Частичное покрытие | $PARTIAL_COVERAGE | $PARTIAL_PERCENT% |" >> "$REPORT_FILE"
echo "| Не покрыто | $NO_COVERAGE | $NO_PERCENT% |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Список непокрытых требований
echo "## Непокрытые требования" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| ID | Описание требования | Приоритет |" >> "$REPORT_FILE"
echo "|---------|------------|---------|" >> "$REPORT_FILE"

# Извлечение непокрытых требований
while IFS= read -r line; do
  req_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
  description=$(echo "$line" | awk -F'|' '{print $3}' | tr -d ' ')
  priority=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' ')
  echo "| $req_id | $description | $priority |" >> "$REPORT_FILE"
done < <(grep -E "Не покрыто" "$MATRIX_FILE" -B1 | grep -E "^| FR-|^| NFR-")

# Список частично покрытых требований
echo "" >> "$REPORT_FILE"
echo "## Частично покрытые требования" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| ID | Описание требования | Приоритет | Тестовые сценарии |" >> "$REPORT_FILE"
echo "|---------|------------|---------|---------|" >> "$REPORT_FILE"

# Извлечение частично покрытых требований
while IFS= read -r line; do
  req_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
  description=$(echo "$line" | awk -F'|' '{print $3}' | tr -d ' ')
  priority=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' ')
  test_cases=$(echo "$line" | awk -F'|' '{print $5}' | tr -d ' ')
  echo "| $req_id | $description | $priority | $test_cases |" >> "$REPORT_FILE"
done < <(grep -E "Частичное" "$MATRIX_FILE" -B1 | grep -E "^| FR-|^| NFR-")

# Рекомендации по улучшению покрытия
echo "" >> "$REPORT_FILE"
echo "## Рекомендации по улучшению покрытия" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "### Приоритетные задачи:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "1. **Разработать тесты для непокрытых высокоприоритетных требований**" >> "$REPORT_FILE"
echo "   - Сосредоточиться на требованиях с высоким приоритетом" >> "$REPORT_FILE"
echo "   - Создать как минимум базовые тесты для критичных функций" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "2. **Расширить существующие тесты для частично покрытых требований**" >> "$REPORT_FILE"
echo "   - Дополнить тестовые сценарии для требований с частичным покрытием" >> "$REPORT_FILE"
echo "   - Уделить особое внимание нефункциональным требованиям" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "3. **Автоматизировать тесты для повышения эффективности**" >> "$REPORT_FILE"
echo "   - Внедрить автоматическое выполнение тестов" >> "$REPORT_FILE"
echo "   - Интегрировать тесты с системой CI/CD" >> "$REPORT_FILE"

echo -e "${GREEN}Отчет о покрытии требований создан:${RESET} $REPORT_FILE"

# Делаем скрипт исполняемым
chmod +x $0
