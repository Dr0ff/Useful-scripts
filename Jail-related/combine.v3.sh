#!/bin/bash
# ЦЕЛЬ: Полностью автоматизировать процесс создания снапшотов и расчета компенсаций.
# 1. Найти точный блок входа в тюрьму.
# 2. Найти рабочий API-узел с помощью двухфакторной проверки.
# 3. Сделать два снапшота: на блоке ДО тюрьмы и на ПЕРВОМ блоке В тюрьме.
# 4. Рассчитать суммы компенсаций на основе созданных снапшотов.
# 5. Поддерживает загрузку настроек из файла compensation.conf и создает его, если он отсутствует.

# --- Фаза 0: Предварительная проверка ---
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v bc &> /dev/null; then
    echo "Ошибка: отсутствуют необходимые утилиты jq, curl или bc." >&2
    exit 1
fi

# --- Фаза 1: Сбор всех необходимых данных ---
CONFIG_FILE="compensation.conf"

# Функция для ручного ввода данных
prompt_for_data() {
    echo "--------------------------------------------------------------------"
    echo "Пожалуйста, введите необходимые данные вручную:"
    read -p "1. Адрес RPC ноды: " NODE
    read -p "2. Valoper адрес валидатора: " VALIDATOR
    read -p "3. Имя демона (daemon) (например: junod): " DAEMON
    read -p "4. Имя сети в Chain Registry (например: juno): " CHAIN_NAME
    echo ""
    echo "--- Укажите диапазон, внутри которого произошел ВХОД в тюрьму ---"
    read -p "5. Начальный блок (когда валидатор был еще ВНЕ тюрьмы): " START_BLOCK
    read -p "6. Конечный блок (когда валидатор был УЖЕ В тюрьме): " END_BLOCK
    echo ""
}

# Основная логика сбора данных
echo "--- Фаза 1: Проверка конфигурации ---"
if [ -f "$CONFIG_FILE" ]; then
    echo "Найден файл конфигурации: $CONFIG_FILE"
    # Загружаем переменные из файла
    source "$CONFIG_FILE"
    
    echo "--- Данные из файла конфигурации ---"
    echo "RPC Нода:         $NODE"
    echo "Адрес валидатора: $VALIDATOR"
    echo "Демон (Daemon):   $DAEMON"
    echo "Имя сети:         $CHAIN_NAME"
    echo "Начальный блок:   $START_BLOCK"
    echo "Конечный блок:    $END_BLOCK"
    echo "-------------------------------------"
    read -p "Использовать эти данные? (Y/n, по умолчанию 'Y'): " use_config
    
    # Если ответ 'n' или 'N', запрашиваем данные вручную. По умолчанию (просто Enter) - используем.
    if [[ "$use_config" == "n" || "$use_config" == "N" ]]; then
        prompt_for_data
    fi
else
    echo "Файл конфигурации '$CONFIG_FILE' не найден. Создаю для вас шаблон..."
    
    # Создаем шаблонный файл конфигурации
    cat <<EOF > "$CONFIG_FILE"
# --- Файл конфигурации для скрипта компенсаций ---
# Этот файл нужен для того, чтобы упростить повторные запуски скрипта,
# избавляя от необходимости вводить одни и те же данные каждый раз.
# Пожалуйста, заполните значения для переменных ниже и запустите скрипт снова.

# Адрес RPC ноды (например: https://juno-rpc.polkachu.com:443)
NODE=""

# Valoper адрес валидатора (например: junovaloper1...)
VALIDATOR=""

# Имя демона (daemon) (например: junod)
DAEMON=""

# Имя сети в Chain Registry (например: juno, stargaze, osmosis)
CHAIN_NAME=""

# Начальный блок (когда валидатор был еще ВНЕ тюрьмы)
START_BLOCK=""

# Конечный блок (когда валидатор был УЖЕ В тюрьме)
END_BLOCK=""
EOF

    echo "✅ Шаблон '$CONFIG_FILE' успешно создан."
    echo "---------------------------------------------------------"
    echo -e "Вы можете выйти сейчас, чтобы заполнить файл (например, командой 'nano $CONFIG_FILE'),\nили продолжить и ввести все данные вручную в этом сеансе."
    read -p "Нажмите Enter для продолжения, или введите 'q' для выхода: " choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Завершение работы. Пожалуйста, заполните '$CONFIG_FILE' и запустите скрипт снова."
        exit 0
    else
        # Продолжаем и запрашиваем данные вручную
        prompt_for_data
    fi
fi

# --- Подтверждение ---
echo ""
echo "--- Пожалуйста, еще раз проверьте итоговые данные ---"
echo "RPC Нода:                 $NODE"
echo "Адрес валидатора:         $VALIDATOR"
echo "Демон (Daemon):           $DAEMON"
echo "Имя сети:                 $CHAIN_NAME"
echo "Диапазон поиска:          с $START_BLOCK по $END_BLOCK"
echo "---------------------------------------------------------"
read -p "Все верно? Нажмите Enter для начала работы..."
echo ""


# --- Фаза 2: Поиск точки ВХОДА в тюрьму ---
query_with_retry() {
    local block_to_check=$1; local attempt=1
    while true; do
        local output=$($DAEMON q staking validator "$VALIDATOR" --height "$block_to_check" --node "$NODE" -o json 2>/dev/null)
        local exit_code=$?
        if [[ $exit_code -eq 0 && -n "$output" ]]; then
            local result=$(echo "$output" | jq '.validator.jailed // false'); echo "$result"; return 0
        fi
        echo "Попытка $attempt не удалась для блока $block_to_check. Повтор..." >&2; sleep 2; ((attempt++))
    done
}

SEARCH_START_BLOCK=$START_BLOCK; SEARCH_END_BLOCK=$END_BLOCK; JAIL_BLOCK=0
echo "--- Фаза 2: Запуск поиска блока входа в тюрьму... ---"
while [[ $SEARCH_START_BLOCK -le $SEARCH_END_BLOCK ]]; do
    MID_BLOCK=$((SEARCH_START_BLOCK + (SEARCH_END_BLOCK - SEARCH_START_BLOCK) / 2))
    if [[ $MID_BLOCK -lt $START_BLOCK || $MID_BLOCK -gt $END_BLOCK ]]; then break; fi
    echo -n "Проверка блока $MID_BLOCK... "; IS_JAILED=$(query_with_retry "$MID_BLOCK"); echo "Статус Jailed: $IS_JAILED"
    if [[ "$IS_JAILED" == "true" ]]; then
        JAIL_BLOCK=$MID_BLOCK; SEARCH_END_BLOCK=$((MID_BLOCK - 1))
    else
        SEARCH_START_BLOCK=$((MID_BLOCK + 1))
    fi
    sleep 0.5
done
echo "---------------------------------------------------------"

# --- Фаза 3: Определение блоков для снапшотов ---
SNAPSHOT_BLOCK_BEFORE=0; SNAPSHOT_BLOCK_JAIL=0
if [[ $JAIL_BLOCK -ne 0 ]]; then
    BLOCK_N=$JAIL_BLOCK; BLOCK_N_MINUS_1=$((JAIL_BLOCK - 1))
    STATUS_N_MINUS_1=$(query_with_retry "$BLOCK_N_MINUS_1"); STATUS_N=$(query_with_retry "$BLOCK_N")
    if [[ "$STATUS_N" == "true" && "$STATUS_N_MINUS_1" == "false" ]]; then
        echo "✅ Переход в тюрьму подтвержден."
        SNAPSHOT_BLOCK_BEFORE=$BLOCK_N_MINUS_1; SNAPSHOT_BLOCK_JAIL=$BLOCK_N
        echo "Блок для первого снапшота (до тюрьмы): $SNAPSHOT_BLOCK_BEFORE"
        echo "Блок для второго снапшота (в тюрьме): $SNAPSHOT_BLOCK_JAIL"
    else
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось точно определить переход. Проверьте исходный диапазон." >&2; exit 1
    fi
else
    echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось найти блок входа в тюрьму в заданном диапазоне." >&2; exit 1
fi
echo "---------------------------------------------------------"
read -p "Блоки для снапшотов определены. Нажмите Enter, чтобы начать их создание..."
echo ""

# --- Фаза 4: УЛУЧШЕННЫЙ поиск рабочего API ---
find_and_test_api() {
    local block_to_check_for_history=$1
    echo "--- Фаза 4: Поиск рабочего API-узла для сети '$CHAIN_NAME' ---" >&2
    echo "Загружаю список API-узлов из Cosmos Chain Registry..." >&2
    
    local registry_url="https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
    local api_list_json=$(curl -sL "$registry_url")
    mapfile -t api_urls < <(echo "$api_list_json" | jq -r '.apis.rest[].address')

    if [ ${#api_urls[@]} -eq 0 ]; then
        echo "Не удалось получить список API-узлов для сети '$CHAIN_NAME'." >&2; return 1
    fi

    echo "Найдено ${#api_urls[@]} API-узлов. Начинаю двухфакторную проверку..." >&2
    echo "---------------------------------------------------------" >&2

    for url in "${api_urls[@]}"; do
        url=$(echo "$url" | sed 's:/*$::') 
        echo -n "Проверяю $url ... " >&2
        
        # Проверка 1: "Живой" ли узел?
        local health_check_url="${url}/cosmos/base/tendermint/v1beta1/node_info"
        local http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -m 10 "$health_check_url")
        if [[ "$http_code" -ne 200 ]]; then
            echo "❌ Не отвечает (код: $http_code)." >&2; continue
        fi

        # Проверка 2: Может ли отдавать исторические данные?
        echo -n "OK. Тест исторического запроса... " >&2
        local historical_test_url="${url}/cosmos/staking/v1beta1/validators/${VALIDATOR}/delegations?pagination.limit=1"
        local historical_response=$(curl --silent -m 20 -H "x-cosmos-block-height: $block_to_check_for_history" -X GET "$historical_test_url")
        if echo "$historical_response" | jq -e '.delegation_responses' > /dev/null; then
             echo "✅ Работает!" >&2; echo "$url"; return 0
        else
            echo "❌ Не справился." >&2
        fi
    done
    
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не найдено ни одного API-узла, прошедшего обе проверки." >&2
    return 1
}

# --- Фаза 5: Функция для создания одного снапшота ---
create_single_snapshot() {
    local snapshot_block=$1; local api_endpoint=$2; local page_size=200
    local output_file="snapshot_${snapshot_block}.csv"; local temp_json_file=$(mktemp)
    
    echo "---------------------------------------------------------" >&2
    echo "--- Создание снапшота на блоке $snapshot_block ---" >&2
    echo "--- (Использую проверенный API: $api_endpoint) ---" >&2

    local next_key="initial"; local page_num=1
    while [[ -n "$next_key" && "$next_key" != "null" ]]; do
        local total_pages_info=""; if [[ -n "$total_delegators" ]]; then total_pages_info=" из ~$total_pages"; fi
        echo "Запрос страницы $page_num$total_pages_info..." >&2
        
        local pagination_param=""; if [[ "$next_key" != "initial" ]]; then local encoded_key=$(printf %s "$next_key" | jq -s -R -r @uri); pagination_param="&pagination.key=$encoded_key"; fi
        local URL="${api_endpoint}/cosmos/staking/v1beta1/validators/${VALIDATOR}/delegations?pagination.limit=${page_size}${pagination_param}"
        
        local attempt=1; local max_retries=15; local response=""
        while [[ $attempt -le $max_retries ]]; do
            response=$(curl --silent -m 60 -H "x-cosmos-block-height: $snapshot_block" -X GET "$URL")
            if echo "$response" | jq -e '.delegation_responses' > /dev/null; then break; fi
            echo "Попытка $attempt/$max_retries не удалась для страницы $page_num. Повтор через 5с..." >&2; sleep 5; ((attempt++))
        done
        if ! echo "$response" | jq -e '.delegation_responses' > /dev/null; then
            echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить данные о делегаторах после $max_retries попыток." >&2; rm "$temp_json_file"; return 1
        fi
        echo "$response" | jq '.delegation_responses' >> "$temp_json_file"; next_key=$(echo "$response" | jq -r '.pagination.next_key')
        if [[ $page_num -eq 1 ]]; then
            total_delegators=$(echo "$response" | jq -r '.pagination.total'); if [[ "$total_delegators" -gt 0 ]]; then total_pages=$(( (total_delegators + page_size - 1) / page_size )); fi
        fi
        ((page_num++)); sleep 1
    done
    echo "Все страницы получены. Конвертация в CSV..." >&2
    jq -r -s 'add | .[] | [.delegation.delegator_address, .balance.amount] | @csv' "$temp_json_file" > "$output_file"
    rm "$temp_json_file"; echo "✅ Снапшот успешно создан: $output_file" >&2; return 0
}

# --- Фаза 6: Расчет компенсации ---
calculate_compensation() {
    local FILE_BEFORE="snapshot_${SNAPSHOT_BLOCK_BEFORE}.csv"; local FILE_AFTER="snapshot_${SNAPSHOT_BLOCK_JAIL}.csv"
    if [ ! -f "$FILE_BEFORE" ] || [ ! -f "$FILE_AFTER" ]; then
        echo "Ошибка: Один из файлов-снапшотов не найден! Расчет невозможен." >&2; return 1
    fi
    
    local ADD_EXTRA_COMPENSATION=false; local EXTRA_PERCENTAGE=25
    echo ""; echo "--- Фаза 6: Настройка и расчет компенсации ---"
    echo "========================================================"
    echo "Опция: Добавить дополнительную компенсацию сверх потерь?"; echo "Текущие настройки:"; echo "  - Дополнительная компенсация: ВЫКЛЮЧЕНА"
    echo "========================================================"
    read -p "Хотите включить доп. компенсацию? (y/n, по умолчанию 'n'): " enable_extra
    
    if [[ "$enable_extra" == "y" || "$enable_extra" == "Y" ]]; then
        ADD_EXTRA_COMPENSATION=true
        read -p "Введите процент дополнительной компенсации (например, 25): " new_percentage
        if [[ "$new_percentage" =~ ^[0-9]+$ ]]; then
            EXTRA_PERCENTAGE=$new_percentage
        else
            echo "Некорректный ввод. Используется значение по умолчанию: 25%"; EXTRA_PERCENTAGE=25
        fi
    fi

    local COMPENSATION_MULTIPLIER=1; local OUTPUT_FILE="compensation_amounts.csv"
    if [ "$ADD_EXTRA_COMPENSATION" = true ]; then
        OUTPUT_FILE="compensation_amounts_${EXTRA_PERCENTAGE}_pc.csv"
        COMPENSATION_MULTIPLIER=$(echo "1 + $EXTRA_PERCENTAGE / 100" | bc -l)
    fi

    echo "---------------------------------"; echo "Начинаю сравнение файлов:"; echo "ДО:    $FILE_BEFORE"; echo "ПОСЛЕ: $FILE_AFTER"
    if [ "$ADD_EXTRA_COMPENSATION" = true ]; then echo "ОПЦИЯ: Компенсация будет умножена на $COMPENSATION_MULTIPLIER (+$EXTRA_PERCENTAGE%)."; else echo "ОПЦИЯ: Расчет компенсации 1-в-1."; fi
    echo "Итоговый файл будет назван: $OUTPUT_FILE"; echo "---------------------------------"

    awk -v multiplier="$COMPENSATION_MULTIPLIER" '
    BEGIN { FS=OFS="," }
    FNR==NR { gsub(/"/, "", $1); gsub(/"/, "", $2); before[$1] = $2; next }
    {
        gsub(/"/, "", $1); gsub(/"/, "", $2);
        loss = before[$1] - $2;
        compensation = 0;
        if (loss > 0) { compensation = loss * multiplier; }
        printf "%s,%.0f\n", $1, compensation;
        delete before[$1]
    }
    END {
        for (addr in before) {
            loss = before[addr];
            compensation = loss * multiplier;
            printf "%s,%.0f\n", addr, compensation;
        }
    }
    ' "$FILE_BEFORE" "$FILE_AFTER" > "$OUTPUT_FILE"

    echo "✅ Расчет завершен."
    echo "Итоговый файл с суммами для компенсации создан: $OUTPUT_FILE"
    return 0
}


# --- Фаза 7: Основной блок выполнения ---
WORKING_API=$(find_and_test_api "$SNAPSHOT_BLOCK_BEFORE")

if [[ $? -eq 0 ]]; then
    create_single_snapshot "$SNAPSHOT_BLOCK_BEFORE" "$WORKING_API"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    create_single_snapshot "$SNAPSHOT_BLOCK_JAIL" "$WORKING_API"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    echo ""; echo "========================================================="
    echo "ГОТОВО! Оба снапшота успешно созданы."
    echo "========================================================="

    calculate_compensation
    
else
    echo "Не удалось продолжить, так как не был найден рабочий API-узел." >&2
    exit 1
fi
