#!/bin/bash
# ЦЕЛЬ: Полностью автоматизировать процесс создания снапшотов и расчета компенсаций.
# ВЕРСИЯ 13.1: Увеличено количество попыток для большей отказоустойчивости.

# --- Фаза 0: Предварительная проверка ---
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v bc &> /dev/null; then
    echo "Ошибка: отсутствуют необходимые утилиты jq, curl или bc." >&2
    exit 1
fi

# --- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ (будут установлены в get_settings) ---
CONFIG_FILE="compensation.conf"
VALIDATOR=""
DAEMON=""
CHAIN_NAME=""
START_BLOCK=""
END_BLOCK=""
KNOWN_JAILED_BLOCK=""
NODE=""
SNAPSHOT_BLOCK_BEFORE=0
SNAPSHOT_BLOCK_JAIL=0

# --- БЛОК ФУНКЦИЙ ---

# Функция для ручного ввода данных. Напрямую устанавливает глобальные переменные.
prompt_for_data() {
    echo "--------------------------------------------------------------------"
    echo "Пожалуйста, введите необходимые данные вручную:"
    read -p "1. Valoper адрес валидатора: " VALIDATOR
    read -p "2. Имя демона (daemon) (например: junod, osmosisd): " DAEMON
    read -p "3. Имя сети в Chain Registry (например: juno, osmosis): " CHAIN_NAME
    echo ""
    echo "--- Выберите режим поиска ---"
    read -p "Вы знаете точный диапазон (start/end block)? (y/n): " know_range
    if [[ "$know_range" == "y" || "$know_range" == "Y" ]]; then
        read -p "  - Начальный блок (когда валидатор был еще ВНЕ тюрьмы): " START_BLOCK
        read -p "  - Конечный блок (когда валидатор был УЖЕ В тюрьме): " END_BLOCK
        START_BLOCK=$(echo "$START_BLOCK" | tr -dc '0-9')
        END_BLOCK=$(echo "$END_BLOCK" | tr -dc '0-9')
        KNOWN_JAILED_BLOCK=""
    else
        read -p "  - Введите ЛЮБОЙ блок, когда валидатор был УЖЕ в тюрьме: " KNOWN_JAILED_BLOCK
        KNOWN_JAILED_BLOCK=$(echo "$KNOWN_JAILED_BLOCK" | tr -dc '0-9')
        START_BLOCK=""
        END_BLOCK=""
    fi
    echo ""
    NODE="" # Сбрасываем ручной ввод RPC при ручном вводе
}

# Функция для получения всех настроек. Возвращает 0 при успехе, 1 при выходе.
get_settings() {
    echo "--- Фаза 1: Проверка конфигурации ---"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Файл '$CONFIG_FILE' не найден. Создаю шаблон..."
        cat <<EOF > "$CONFIG_FILE"
# --- Файл конфигурации для скрипта компенсаций ---
#
# *** ВЫБЕРИТЕ ОДИН ИЗ ДВУХ РЕЖИМОВ ПОИСКА ***
#
# Режим 1: Укажите точный диапазон.
START_BLOCK=""
END_BLOCK=""
#
# Режим 2: Укажите только ОДИН блок (оставьте START_BLOCK и END_BLOCK пустыми).
KNOWN_JAILED_BLOCK=""

# --- ОБЩИЕ НАСТРОЙКИ ---
# Valoper адрес валидатора.
VALIDATOR=""
# Имя демона (daemon), например: junod, osmosisd, sommelier
DAEMON=""
# Имя сети в Chain Registry, например: juno, osmosis, sommelier
CHAIN_NAME=""

# Опционально: укажите конкретный RPC, чтобы пропустить автопоиск.
# По умолчанию используется прокси https://rpc.cosmos.directory/{CHAIN_NAME}
NODE=""
EOF
        echo "✅ Шаблон '$CONFIG_FILE' создан."
        echo "Завершение работы. Пожалуйста, заполните '$CONFIG_FILE' и запустите скрипт снова."
        return 1
    fi

    source "$CONFIG_FILE"
    
    if [ -z "$VALIDATOR" ] || [ -z "$DAEMON" ] || [ -z "$CHAIN_NAME" ] || ([ -z "$START_BLOCK" ] && [ -z "$KNOWN_JAILED_BLOCK" ]); then
        echo "Предупреждение: Файл '$CONFIG_FILE' не заполнен."
        read -p "Нажмите Enter для ввода данных вручную, или введите 'q' для выхода: " choice
        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then echo "Выход."; return 1; else prompt_for_data; fi
    else
        echo "--- Данные из файла конфигурации ---"
        echo "Адрес валидатора: $VALIDATOR"
        echo "Демон (Daemon):   $DAEMON"
        echo "Имя сети:         $CHAIN_NAME"
        if [ -n "$START_BLOCK" ]; then echo "Режим поиска:     Диапазон ($START_BLOCK -> $END_BLOCK)"; else echo "Режим поиска:     Обратный от блока $KNOWN_JAILED_BLOCK"; fi
        echo "-------------------------------------"; read -p "Использовать эти данные? (Y/n): " use_config
        
        if [[ "$use_config" == "n" || "$use_config" == "N" ]]; then
            prompt_for_data
        fi
    fi
    return 0
}

# Функция для принудительного добавления порта :443 к https URL
format_url() {
    local url=$1; if [[ $url == https://* ]] && ! [[ $(echo "$url" | cut -d/ -f3) =~ .*:.* ]]; then echo "$url" | sed -E 's|^(https://[^/]+)|\1:443|'; else echo "$url"; fi
}

# --- Фаза 2: Поиск точки ВХОДА в тюрьму ---
query_with_retry() {
    local block_to_check=$1; local rpc_node=$2;
    local attempt=1; 
    # ИЗМЕНЕНО: Увеличено количество попыток
    local max_attempts=10
    
    while [[ $attempt -le $max_attempts ]]; do
        local response; response=$($DAEMON q staking validator "$VALIDATOR" --height "$block_to_check" --node "$rpc_node" -o json 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]] && echo "$response" | jq -e . > /dev/null 2>&1; then
            echo "$(echo "$response" | jq '.validator.jailed // false')"; 
            return 0
        fi

        echo "" >&2
        echo "ПОДРОБНАЯ ОШИБКА для блока $block_to_check (попытка $attempt/$max_attempts):" >&2
        echo "----------------------------------------------------" >&2
        echo "$response" >&2
        echo "----------------------------------------------------" >&2
        
        if [[ $attempt -lt $max_attempts ]]; then echo "Повтор через 7 секунд..." >&2; sleep 7; fi
        ((attempt++))
    done
    
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить ответ от RPC-узла для блока $block_to_check после $max_attempts попыток." >&2
    return 1
}
find_search_range_backwards() {
    local rpc_node=$1; local current_block=$KNOWN_JAILED_BLOCK; local step=1000;
    echo "--- Фаза 3.1: Обратный поиск для определения диапазона... ---"
    while true; do
        local check_block=$((current_block - step)); if [ "$check_block" -le 0 ]; then check_block=1; fi
        echo -n "Прыжок назад на $step блоков к блоку $check_block... "; 
        local is_jailed; is_jailed=$(query_with_retry "$check_block" "$rpc_node")
        if [[ $? -ne 0 ]]; then return 1; fi
        echo "Статус Jailed: $is_jailed"
        if [[ "$is_jailed" == "false" ]]; then 
            export SEARCH_START_BLOCK=$check_block
            export SEARCH_END_BLOCK=$current_block
            echo "✅ Диапазон найден: [$SEARCH_START_BLOCK ... $SEARCH_END_BLOCK]"; return 0;
        fi
        current_block=$check_block; step=$((step * 2)); if [ "$current_block" -le 1 ]; then echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Достигли первого блока." >&2; return 1; fi
    done
}
run_jail_search() {
    local rpc_node=$1; 
    local search_start=$SEARCH_START_BLOCK; local search_end=$SEARCH_END_BLOCK;
    local jail_block=0
    
    echo "--- Фаза 3.2: Запуск точного бинарного поиска в диапазоне [$search_start ... $search_end]... ---"
    while [[ $search_start -le $search_end ]]; do
        local mid_block=$((search_start + (search_end - search_start) / 2)); if [[ $mid_block -lt $SEARCH_START_BLOCK || $mid_block -gt $SEARCH_END_BLOCK ]]; then break; fi
        echo -n "Проверка блока $mid_block... "; 
        local is_jailed; is_jailed=$(query_with_retry "$mid_block" "$rpc_node")
        if [[ $? -ne 0 ]]; then return 1; fi
        echo "Статус Jailed: $is_jailed"
        if [[ "$is_jailed" == "true" ]]; then jail_block=$mid_block; search_end=$((mid_block - 1)); else search_start=$((mid_block + 1)); fi
        sleep 0.5
    done
    
    echo "---------------------------------------------------------"
    if [[ $jail_block -ne 0 ]]; then
        local block_n=$jail_block; local block_n_minus_1=$((jail_block - 1));
        local status_n_minus_1; status_n_minus_1=$(query_with_retry "$block_n_minus_1" "$rpc_node"); if [[ $? -ne 0 ]]; then return 1; fi
        local status_n; status_n=$(query_with_retry "$block_n" "$rpc_node"); if [[ $? -ne 0 ]]; then return 1; fi
        
        if [[ "$status_n" == "true" && "$status_n_minus_1" == "false" ]]; then
            echo "✅ Переход в тюрьму подтвержден.";
            export SNAPSHOT_BLOCK_BEFORE=$block_n_minus_1
            export SNAPSHOT_BLOCK_JAIL=$block_n
            echo "Блок для первого снапшота (до тюрьмы): $SNAPSHOT_BLOCK_BEFORE"; echo "Блок для второго снапшота (в тюрьме): $SNAPSHOT_BLOCK_JAIL"; return 0
        else echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось точно определить переход." >&2; return 1; fi
    else echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось найти блок входа в тюрьму." >&2; return 1; fi
}

# --- Фаза 4: Поиск рабочего API ---
find_and_test_api() {
    echo "--- Фаза 4: Поиск рабочего API-узла для сети '$CHAIN_NAME'... ---" >&2
    local registry_url="https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
    local api_list_json; api_list_json=$(curl -sL "$registry_url"); mapfile -t api_urls < <(echo "$api_list_json" | jq -r '.apis.rest[].address')
    if [ ${#api_urls[@]} -eq 0 ]; then echo "Не удалось получить список API-узлов." >&2; return 1; fi
    echo "Найдено ${#api_urls[@]} API-узлов. Проверка..." >&2; for url in "${api_urls[@]}"; do url=$(echo "$url" | sed 's:/*$::'); echo -n "Проверяю $url ... " >&2; local http_code; http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -m 10 "${url}/cosmos/base/tendermint/v1beta1/node_info"); if [[ "$http_code" -eq 200 ]]; then echo "✅ OK" >&2; echo "$url"; return 0; else echo "❌ Fail" >&2; fi; done
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не найдено рабочих API." >&2; return 1
}

# --- Фаза 5: Функция для создания одного снапшота ---
create_single_snapshot() {
    local snapshot_block=$1; local api_endpoint=$2;
    local page_size=200; local output_file="snapshot_${snapshot_block}.csv"; local temp_json_file; temp_json_file=$(mktemp)
    echo "---------------------------------------------------------" >&2; echo "--- Создание снапшота на блоке $snapshot_block ---" >&2; local next_key="initial"; local page_num=1
    while [[ -n "$next_key" && "$next_key" != "null" ]]; do local total_pages_info=""; if [[ -n "$total_delegators" ]]; then total_pages_info=" из ~$total_pages"; fi; echo "Запрос страницы $page_num$total_pages_info..." >&2; local pagination_param=""; if [[ "$next_key" != "initial" ]]; then local encoded_key; encoded_key=$(printf %s "$next_key" | jq -s -R -r @uri); pagination_param="&pagination.key=$encoded_key"; fi
        local URL="${api_endpoint}/cosmos/staking/v1beta1/validators/${VALIDATOR}/delegations?pagination.limit=${page_size}${pagination_param}"; local attempt=1; local max_retries=15; local response=""
        while [[ $attempt -le $max_retries ]]; do response=$(curl --silent -m 60 -H "x-cosmos-block-height: $snapshot_block" -X GET "$URL"); if echo "$response" | jq -e '.delegation_responses' > /dev/null; then break; fi; echo "Попытка $attempt/$max_retries не удалась. Повтор..." >&2; sleep 5; ((attempt++)); done
        if ! echo "$response" | jq -e '.delegation_responses' > /dev/null; then echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить данные." >&2; rm "$temp_json_file"; return 1; fi
        echo "$response" | jq '.delegation_responses' >> "$temp_json_file"; next_key=$(echo "$response" | jq -r '.pagination.next_key'); if [[ $page_num -eq 1 ]]; then total_delegators=$(echo "$response" | jq -r '.pagination.total'); if [[ "$total_delegators" -gt 0 ]]; then total_pages=$(( (total_delegators + page_size - 1) / page_size )); fi; fi; ((page_num++)); sleep 1; done
    echo "Конвертация в CSV..." >&2; jq -r -s 'add | .[] | [.delegation.delegator_address, .balance.amount] | @csv' "$temp_json_file" > "$output_file"; rm "$temp_json_file"; echo "✅ Снапшот создан: $output_file" >&2; return 0
}

# --- Фаза 6: Расчет компенсации ---
calculate_compensation() {
    local file_before=$1; local file_after=$2;
    if [ ! -f "$file_before" ] || [ ! -f "$file_after" ]; then echo "Ошибка: Файлы снапшотов не найдены." >&2; return 1; fi
    local add_extra_compensation=false; local extra_percentage=25; echo ""; echo "--- Фаза 6: Настройка и расчет компенсации ---"; read -p "Включить доп. компенсацию? (y/n): " enable_extra
    if [[ "$enable_extra" == "y" || "$enable_extra" == "Y" ]]; then add_extra_compensation=true; read -p "Процент доп. компенсации (e.g., 25): " new_percentage; if [[ "$new_percentage" =~ ^[0-9]+$ ]]; then extra_percentage=$new_percentage; else extra_percentage=25; fi; fi
    local compensation_multiplier=1; local output_file="compensation_amounts.csv"; if [ "$add_extra_compensation" = true ]; then output_file="compensation_amounts_${extra_percentage}_pc.csv"; compensation_multiplier=$(echo "1 + $extra_percentage / 100" | bc -l); fi
    echo "Сравнение файлов..."; awk -v multiplier="$compensation_multiplier" 'BEGIN { FS=OFS="," } FNR==NR { gsub(/"/, "", $1); gsub(/"/, "", $2); before[$1] = $2; next } { gsub(/"/, "", $1); gsub(/"/, "", $2); loss = before[$1] - $2; compensation = 0; if (loss > 0) { compensation = loss * multiplier; } printf "%s,%.0f\n", $1, compensation; delete before[$1] } END { for (addr in before) { loss = before[addr]; compensation = loss * multiplier; printf "%s,%.0f\n", addr, compensation; } }' "$file_before" "$file_after" > "$output_file"
    echo "✅ Расчет завершен: $OUTPUT_FILE"
}

# --- Основной блок выполнения ---
main() {
    # Получаем все настройки в глобальные переменные
    get_settings
    if [[ $? -ne 0 ]]; then exit 0; fi

    # --- Подтверждение ---
    echo ""; echo "--- Пожалуйста, еще раз проверьте итоговые данные ---"
    if [[ -n "$NODE" ]]; then echo "RPC Нода:                  $NODE (указано вручную)"; else echo "RPC Нода:                  <будет использован прокси-узел>"; fi
    echo "Адрес валидатора:          $VALIDATOR"; echo "Демон (Daemon):            $DAEMON"; echo "Имя сети:                  $CHAIN_NAME"
    if [ -n "$START_BLOCK" ]; then echo "Режим поиска:              Диапазон ($START_BLOCK -> $END_BLOCK)"; else echo "Режим поиска:              Обратный от блока $KNOWN_JAILED_BLOCK"; fi
    echo "---------------------------------------------------------"
    read -p "Все верно? Нажмите Enter для начала работы..."; echo ""

    local rpc_node
    if [[ -z "$NODE" ]]; then
        rpc_node=$(format_url "https://rpc.cosmos.directory/${CHAIN_NAME}")
        echo "--- Фаза 2: Используется прокси-узел по умолчанию: $rpc_node ---"
    else
        rpc_node=$(format_url "$NODE")
        echo "--- Фаза 2: Используется RPC-узел из файла конфигурации: $rpc_node ---"
    fi
    echo "---------------------------------------------------------"

    if [[ -z "$START_BLOCK" && -n "$KNOWN_JAILED_BLOCK" ]]; then
        find_search_range_backwards "$rpc_node"
        if [[ $? -ne 0 ]]; then exit 1; fi
    fi

    run_jail_search "$rpc_node"
    if [[ $? -ne 0 ]]; then exit 1; fi
    echo "---------------------------------------------------------"
    read -p "Блоки для снапшотов определены. Нажмите Enter для создания..."
    echo ""

    local working_api; working_api=$(find_and_test_api)
    if [[ $? -ne 0 ]]; then exit 1; fi
    echo "---------------------------------------------------------"

    create_single_snapshot "$SNAPSHOT_BLOCK_BEFORE" "$working_api"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    create_single_snapshot "$SNAPSHOT_BLOCK_JAIL" "$working_api"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    echo ""; echo "========================================================="
    echo "ГОТОВО! Оба снапшота успешно созданы."
    echo "========================================================="

    calculate_compensation
}

# Запуск основной функции
main
