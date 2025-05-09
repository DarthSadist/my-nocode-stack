#!/bin/bash

# Создание директории для документации по тестированию
echo "Создание директории для документации по тестированию..."
mkdir -p /home/den/my-nocode-stack/test-docs

# Перемещение всех файлов тестирования в новую директорию
echo "Перемещение файлов тестирования в новую директорию..."
mv /home/den/my-nocode-stack/*testing*.md /home/den/my-nocode-stack/test-docs/

# Копирование основного плана тестирования
echo "Копирование основного плана тестирования..."
cp /home/den/my-nocode-stack/test-plan.md /home/den/my-nocode-stack/test-docs/
cp /home/den/my-nocode-stack/test-plan-part2.md /home/den/my-nocode-stack/test-docs/ 2>/dev/null

echo "Организация файлов тестирования завершена."
echo "Все файлы перемещены в директорию /home/den/my-nocode-stack/test-docs/"
