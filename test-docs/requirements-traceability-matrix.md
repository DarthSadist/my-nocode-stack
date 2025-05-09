# Матрица соответствия требований и тестовых сценариев

## Введение

Данный документ представляет матрицу соответствия требований и тестовых сценариев для проекта "My NoCode Stack". Матрица обеспечивает прослеживаемость между функциональными и нефункциональными требованиями системы и тестовыми сценариями, разработанными для их проверки.

## Структура матрицы

Матрица имеет следующую структуру:

- **ID требования** - уникальный идентификатор требования
- **Описание требования** - краткое описание требования
- **Приоритет** - приоритет требования (Высокий, Средний, Низкий)
- **Тип требования** - функциональное или нефункциональное
- **Тестовые сценарии** - ссылки на тестовые сценарии, проверяющие данное требование
- **Статус покрытия** - статус покрытия требования тестами (Полное, Частичное, Не покрыто)

## Матрица соответствия

### Функциональные требования

| ID     | Описание требования                                             | Приоритет | Тестовые сценарии | Статус покрытия |
|--------|----------------------------------------------------------------|-----------|-------------------|-----------------|
| FR-001 | Система должна предоставлять доступ к компоненту WordPress      | Высокий   | [wordpress-testing-improved.md](/home/den/my-nocode-stack/test-docs/wordpress-testing-improved.md) | Полное         |
| FR-002 | Система должна предоставлять доступ к базе данных PostgreSQL    | Высокий   | [postgres-testing-improved.md](/home/den/my-nocode-stack/test-docs/postgres-testing-improved.md) | Полное         |
| FR-003 | Система должна предоставлять доступ к компоненту N8N            | Высокий   | [n8n-testing-improved.md](/home/den/my-nocode-stack/test-docs/n8n-testing-improved.md) | Полное         |
| FR-004 | Система должна предоставлять доступ к компоненту Flowise        | Высокий   | [flowise-testing-improved.md](/home/den/my-nocode-stack/test-docs/flowise-testing-improved.md) | Полное         |
| FR-005 | Система должна предоставлять доступ к компоненту Qdrant         | Высокий   | [qdrant-testing-improved.md](/home/den/my-nocode-stack/test-docs/qdrant-testing-improved.md) | Полное         |
| FR-006 | Система должна обеспечивать взаимодействие между компонентами   | Высокий   | [integration-testing-improved-part1.md](/home/den/my-nocode-stack/test-docs/integration-testing-improved-part1.md) | Полное         |
| FR-007 | Система должна предоставлять доступ к базе данных MariaDB       | Средний   | [mariadb-testing-improved.md](/home/den/my-nocode-stack/test-docs/mariadb-testing-improved.md) | Полное         |
| FR-008 | Система должна иметь веб-интерфейс для управления компонентами  | Средний   | [ui-testing-improved.md](/home/den/my-nocode-stack/test-docs/ui-testing-improved.md) | Частичное      |
| FR-009 | Система должна обеспечивать резервное копирование данных        | Средний   | [backup-testing-improved.md](/home/den/my-nocode-stack/test-docs/backup-testing-improved.md) | Не покрыто     |
| FR-010 | Система должна обеспечивать аутентификацию пользователей        | Высокий   | [security-testing-improved-part1.md](/home/den/my-nocode-stack/test-docs/security-testing-improved-part1.md) | Полное         |

### Нефункциональные требования

| ID     | Описание требования                                             | Приоритет | Тестовые сценарии | Статус покрытия |
|--------|----------------------------------------------------------------|-----------|-------------------|-----------------|
| NFR-001 | Система должна обрабатывать не менее 100 одновременных запросов | Высокий   | [load-testing-improved-part1.md](/home/den/my-nocode-stack/test-docs/load-testing-improved-part1.md) | Полное         |
| NFR-002 | Время отклика системы не должно превышать 2 секунды            | Высокий   | [load-testing-improved-part2.md](/home/den/my-nocode-stack/test-docs/load-testing-improved-part2.md) | Полное         |
| NFR-003 | Система должна быть доступна 99.9% времени                     | Высокий   | [load-testing-improved-part3.md](/home/den/my-nocode-stack/test-docs/load-testing-improved-part3.md) | Частичное      |
| NFR-004 | Система должна соответствовать стандартам безопасности OWASP    | Высокий   | [security-testing-improved-part2.md](/home/den/my-nocode-stack/test-docs/security-testing-improved-part2.md) | Полное         |
| NFR-005 | Все данные должны быть зашифрованы в состоянии покоя и передачи | Высокий   | [security-testing-improved-part3.md](/home/den/my-nocode-stack/test-docs/security-testing-improved-part3.md) | Частичное      |
| NFR-006 | Система должна быть масштабируема до 1000 пользователей         | Средний   | [load-testing-improved-part4.md](/home/den/my-nocode-stack/test-docs/load-testing-improved-part4.md) | Частичное      |
| NFR-007 | Система должна поддерживать резервное копирование данных        | Средний   | [backup-testing-improved.md](/home/den/my-nocode-stack/test-docs/backup-testing-improved.md) | Не покрыто     |
| NFR-008 | Система должна иметь интуитивно понятный интерфейс              | Низкий    | [ui-testing-improved.md](/home/den/my-nocode-stack/test-docs/ui-testing-improved.md) | Частичное      |
