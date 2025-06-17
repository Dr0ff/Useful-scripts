#!/bin/bash
# ЦЕЛЬ: Полностью автоматизировать процесс создания снапшотов и расчета компенсаций.
# 1. Автоматически обновлять и использовать список RPC-узлов из файла конфигурации.
# 2. Находить рабочий узел с нужной историей блоков.
# 3. Находить точный блок входа в тюрьму.
# 4. Создавать два снапшота и рассчитывать компенсацию.

# --- Фаза 0: Предварительная проверка ---
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || ! command -v bc &> /dev/null; then
    echo "Ошибка: отсутствуют необходимые утилиты jq, curl или bc." >&2
    exit 1
fi

# --- Фаза 1: Управление конфигурацией и сбор данных ---
CONFIG_FILE="compensation.conf"
RPC_LIST_START_MARKER="# --- AUTO-RPC-LIST-START ---"
RPC_LIST_END_MARKER="# --- AUTO-RPC-LIST-END ---"

# Функция для ручного ввода данных
prompt_for_data() {
    echo "--------------------------------------------------------------------"
    echo "Пожалуйста, введите необходимые данные вручную:"
    read -p "1. Valoper адрес валидатора: " VALIDATOR
    read -p "2. Имя демона (daemon) (например: junod): " DAEMON
    read -p "3. Имя сети в Chain Registry (например: juno): " CHAIN_NAME
    echo ""
    echo "--- Укажите диапазон, внутри которого произошел ВХОД в тюрьму ---"
    read -p "4. Начальный блок (когда валидатор был еще ВНЕ тюрьмы): " START_BLOCK
    read -p "5. Конечный блок (когда валидатор был УЖЕ В тюрьме): " END_BLOCK
    echo ""
    NODE="" # Убедимся, что NODE пуст для автопоиска
}

# Функция для обновления списка RPC в файле конфигурации
update_rpc_list_in_config() {
    if [[ -z "$CHAIN_NAME" ]]; then
        echo "Предупреждение: имя сети (CHAIN_NAME) не указано. Пропускаю обновление списка RPC." >&2
        return
    fi
    
    echo "Обновляю список RPC-узлов для сети '$CHAIN_NAME'..."
    local registry_url="https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
    
    mapfile -t registry_rpcs < <(curl -sL "$registry_url" | jq -r '.apis.rpc[].address')
    if [ ${#registry_rpcs[@]} -eq 0 ]; then
        echo "Предупреждение: не удалось получить свежий список RPC. Будет использован существующий список из конфига."
    fi
    
    local proxy_rpc="https://rpc.cosmos.directory/${CHAIN_NAME}"
    local fresh_rpcs=("$proxy_rpc" "${registry_rpcs[@]}")

    local new_rpcs_found=false
    local final_rpcs=("${PUBLIC_RPCS[@]}")

    for rpc in "${fresh_rpcs[@]}"; do
        if ! [[ " ${final_rpcs[*]} " =~ " ${rpc} " ]]; then
            final_rpcs+=("$rpc")
            new_rpcs_found=true
        fi
    done

    if [ "$new_rpcs_found" = true ]; then
        echo "Найдены новые или отсутствующие RPC-узлы. Обновляю файл '$CONFIG_FILE'..."
        local temp_file; temp_file=$(mktemp)
        sed "/$RPC_LIST_START_MARKER/q" "$CONFIG_FILE" > "$temp_file"
        sed -i '$ d' "$temp_file"
        {
            echo "$RPC_LIST_START_MARKER"
            echo "# Этот список обновляется автоматически. Ноды вверху имеют приоритет."
            echo "PUBLIC_RPCS=("
            for rpc_url in "${final_rpcs[@]}"; do
                echo "    \"$rpc_url\""
            done
            echo ")"
            echo "$RPC_LIST_END_MARKER"
        } >> "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        echo "✅ Файл конфигурации обновлен."
    else
        echo "Новых RPC-узлов не найдено. Список в конфиге актуален."
    fi
}

# Новая функция для обработки пустого/ненайденного конфига
handle_missing_or_empty_config() {
    local message=$1
    echo "$message"
    echo "---------------------------------------------------------"
    read -p "Нажмите Enter для продолжения и ввода данных вручную, или введите 'q' для выхода и заполнения файла: " choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Завершение работы. Пожалуйста, заполните '$CONFIG_FILE' и запустите скрипт снова."
        exit 0
    else
        prompt_for_data
    fi
}

# Основная логика сбора данных
echo "--- Фаза 1: Проверка конфигурации ---"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Файл конфигурации '$CONFIG_FILE' не найден. Создаю для вас шаблон..."
    cat <<EOF > "$CONFIG_FILE"
# --- Файл конфигурации для скрипта компенсаций ---
# Этот файл нужен для того, чтобы упростить повторные запуски скрипта.
# Пожалуйста, заполните значения для переменных ниже и запустите скрипт снова.

# Адрес RPC ноды. Если указан, автопоиск и список ниже ИГНОРИРУЮТСЯ.
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

$RPC_LIST_START_MARKER
# Этот список обновляется автоматически. Прокси-узел (rpc.cosmos.directory) будет добавлен и проверен первым.
PUBLIC_RPCS=(
)
$RPC_LIST_END_MARKER
EOF
    echo "✅ Шаблон '$CONFIG_FILE' успешно создан."
    handle_missing_or_empty_config "Вы можете заполнить файл сейчас или ввести данные вручную."

else
    source "$CONFIG_FILE"
    if [ -z "$VALIDATOR" ] || [ -z "$DAEMON" ] || [ -z "$CHAIN_NAME" ] || [ -z "$START_BLOCK" ] || [ -z "$END_BLOCK" ]; then
        handle_missing_or_empty_config "Предупреждение: Файл конфигурации '$CONFIG_FILE' найден, но он не заполнен."
    else
        update_rpc_list_in_config
        source "$CONFIG_FILE" 

        echo "--- Данные из файла конфигурации ---"
        if [[ -n "$NODE" ]]; then echo "RPC Нода (из конфига): $NODE"; else echo "RPC Нода (из конфига): <автопоиск из списка>"; fi
        echo "Адрес валидатора:      $VALIDATOR"; echo "Демон (Daemon):        $DAEMON"; echo "Имя сети:              $CHAIN_NAME"
        echo "Начальный блок:        $START_BLOCK"; echo "Конечный блок:         $END_BLOCK"
        echo "-------------------------------------"; read -p "Использовать эти данные? (Y/n): " use_config
        if [[ "$use_config" == "n" || "$use_config" == "N" ]]; then
            prompt_for_data
        fi
    fi
fi


# --- Подтверждение ---
echo ""; echo "--- Пожалуйста, еще раз проверьте итоговые данные ---"
if [[ -n "$NODE" ]]; then echo "RPC Нода:                  $NODE (указано вручную)"; else echo "RPC Нода:                  <будет найден автоматически из списка в конфиге>"; fi
echo "Адрес валидатора:          $VALIDATOR"; echo "Демон (Daemon):            $DAEMON"; echo "Имя сети:                  $CHAIN_NAME"
echo "Диапазон поиска:           с $START_BLOCK по $END_BLOCK"; echo "---------------------------------------------------------"
read -p "Все верно? Нажмите Enter для начала работы..."; echo ""

# Функция для принудительного добавления порта :443 к https URL
format_url() {
    local url=$1
    if [[ $url == https://* ]] && ! [[ $(echo "$url" | cut -d/ -f3) =~ .*:.* ]]; then
        echo "$url" | sed -E 's|^(https://[^/]+)|\1:443|'
    else
        echo "$url"
    fi
}

# --- Фаза 2: Проверка RPC-узлов ---
test_rpc_list() {
    local oldest_block_needed=$1; shift; 
    local proxy_rpc="https://rpc.cosmos.directory/${CHAIN_NAME}"
    local rpc_list_to_test=("$@")

    local final_test_list=()
    final_test_list+=("$proxy_rpc")
    for rpc in "${rpc_list_to_test[@]}"; do
        if [[ "$rpc" != "$proxy_rpc" ]]; then
            final_test_list+=("$rpc")
        fi
    done

    echo "--- Фаза 2: Проверка RPC-узлов (прокси-узел имеет приоритет)... ---" >&2
    local working_rpcs=()
    for url in "${final_test_list[@]}"; do
        url=$(format_url "$(echo "$url" | sed 's:/*$::')")
        echo -n "Проверяю $url ... " >&2
        
        # УМНАЯ ПРОВЕРКА: запрашиваем статус и смотрим на earliest_block_height
        local status_url="${url}/status"; local response
        response=$(curl --silent -m 10 "$status_url")
        local earliest_block; earliest_block=$(echo "$response" | jq -r '.result.sync_info.earliest_block_height // "0"')

        # Проверяем, что нода не догоняет и что ее история достаточно глубока
        if [[ $(echo "$response" | jq -r '.result.sync_info.catching_up') == "false" && "$earliest_block" -le "$oldest_block_needed" ]]; then
             echo "✅ ОК! (История с блока $earliest_block)" >&2
             working_rpcs+=("$url")
        else
            echo "❌ Проблема: не синхронизирован или нет нужной истории (самый ранний блок: $earliest_block)." >&2
        fi
    done
    
    if [ ${#working_rpcs[@]} -gt 0 ]; then echo "${working_rpcs[@]}"; else
        echo "КРИТИЧЕСКАЯ ОШИБКА: Не найдено ни одного рабочего RPC-узла с необходимой историей блоков." >&2; return 1;
    fi
}

# --- Фаза 3: Поиск точки ВХОДА в тюрьму ---
query_with_retry() {
    local block_to_check=$1; shift; local rpc_list=("$@"); local attempt=1
    while true; do
        for rpc_node in "${rpc_list[@]}"; do
            local output; output=$($DAEMON q staking validator "$VALIDATOR" --height "$block_to_check" --node "$rpc_node" -o json 2>/dev/null)
            if [[ $? -eq 0 && -n "$output" ]]; then echo "$(echo "$output" | jq '.validator.jailed // false')"; return 0; fi
        done
        echo "Все RPC не ответили для блока $block_to_check. Повтор через 5 секунд (попытка $attempt)..." >&2; sleep 5; ((attempt++))
    done
}
run_jail_search() {
    local -a rpc_list=("$@"); SEARCH_START_BLOCK=$START_BLOCK; SEARCH_END_BLOCK=$END_BLOCK; JAIL_BLOCK=0
    echo "--- Фаза 3: Запуск поиска блока входа в тюрьму... ---"
    while [[ $SEARCH_START_BLOCK -le $SEARCH_END_BLOCK ]]; do
        MID_BLOCK=$((SEARCH_START_BLOCK + (SEARCH_END_BLOCK - SEARCH_START_BLOCK) / 2))
        if [[ $MID_BLOCK -lt $START_BLOCK || $MID_BLOCK -gt $END_BLOCK ]]; then break; fi
        echo -n "Проверка блока $MID_BLOCK... "; IS_JAILED=$(query_with_retry "$MID_BLOCK" "${rpc_list[@]}"); echo "Статус Jailed: $IS_JAILED"
        if [[ "$IS_JAILED" == "true" ]]; then JAIL_BLOCK=$MID_BLOCK; SEARCH_END_BLOCK=$((MID_BLOCK - 1)); else SEARCH_START_BLOCK=$((MID_BLOCK + 1)); fi
        sleep 0.5
    done
    echo "---------------------------------------------------------"
    if [[ $JAIL_BLOCK -ne 0 ]]; then
        BLOCK_N=$JAIL_BLOCK; BLOCK_N_MINUS_1=$((JAIL_BLOCK - 1)); STATUS_N_MINUS_1=$(query_with_retry "$BLOCK_N_MINUS_1" "${rpc_list[@]}"); STATUS_N=$(query_with_retry "$BLOCK_N" "${rpc_list[@]}");
        if [[ "$STATUS_N" == "true" && "$STATUS_N_MINUS_1" == "false" ]]; then
            echo "✅ Переход в тюрьму подтвержден."; export SNAPSHOT_BLOCK_BEFORE=$BLOCK_N_MINUS_1; export SNAPSHOT_BLOCK_JAIL=$BLOCK_N
            echo "Блок для первого снапшота (до тюрьмы): $SNAPSHOT_BLOCK_BEFORE"; echo "Блок для второго снапшота (в тюрьме): $SNAPSHOT_BLOCK_JAIL"; return 0
        else echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось точно определить переход." >&2; return 1; fi
    else echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось найти блок входа в тюрьму." >&2; return 1; fi
}

# --- Фаза 4: Поиск рабочего API ---
find_and_test_api() {
    echo "--- Фаза 4: Поиск рабочего API-узла для сети '$CHAIN_NAME' ---" >&2
    local registry_url="https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
    local api_list_json; api_list_json=$(curl -sL "$registry_url"); mapfile -t api_urls < <(echo "$api_list_json" | jq -r '.apis.rest[].address')
    if [ ${#api_urls[@]} -eq 0 ]; then echo "Не удалось получить список API-узлов для сети '$CHAIN_NAME'." >&2; return 1; fi
    echo "Найдено ${#api_urls[@]} API-узлов. Начинаю проверку..." >&2; echo "---------------------------------------------------------" >&2
    for url in "${api_urls[@]}"; do
        url=$(format_url "$(echo "$url" | sed 's:/*$::')")
        echo -n "Проверяю $url ... " >&2
        local http_code; http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -m 10 "${url}/cosmos/base/tendermint/v1beta1/node_info")
        if [[ "$http_code" -eq 200 ]]; then echo "✅ Работает!" >&2; echo "$url"; return 0; else echo "❌ Не отвечает (код: $http_code)." >&2; fi
    done
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не найдено ни одного рабочего API-узла." >&2; return 1
}

# --- Фаза 5: Функция для создания одного снапшота ---
create_single_snapshot() {
    local snapshot_block=$1; local api_endpoint=$2; local page_size=200
    local output_file="snapshot_${snapshot_block}.csv"; local temp_json_file; temp_json_file=$(mktemp)
    echo "---------------------------------------------------------" >&2; echo "--- Создание снапшота на блоке $snapshot_block ---" >&2
    echo "--- (Использую проверенный API: $api_endpoint) ---" >&2
    local next_key="initial"; local page_num=1
    while [[ -n "$next_key" && "$next_key" != "null" ]]; do
        local total_pages_info=""; if [[ -n "$total_delegators" ]]; then total_pages_info=" из ~$total_pages"; fi
        echo "Запрос страницы $page_num$total_pages_info..." >&2
        local pagination_param=""; if [[ "$next_key" != "initial" ]]; then local encoded_key; encoded_key=$(printf %s "$next_key" | jq -s -R -r @uri); pagination_param="&pagination.key=$encoded_key"; fi
        local URL="${api_endpoint}/cosmos/staking/v1beta1/validators/${VALIDATOR}/delegations?pagination.limit=${page_size}${pagination_param}"
        local attempt=1; local max_retries=15; local response=""
        while [[ $attempt -le $max_retries ]]; do
            response=$(curl --silent -m 60 -H "x-cosmos-block-height: $snapshot_block" -X GET "$URL")
            if echo "$response" | jq -e '.delegation_responses' > /dev/null; then break; fi
            echo "Попытка $attempt/$max_retries не удалась. Повтор через 5с..." >&2; sleep 5; ((attempt++))
        done
        if ! echo "$response" | jq -e '.delegation_responses' > /dev/null; then echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить данные о делегаторах." >&2; rm "$temp_json_file"; return 1; fi
        echo "$response" | jq '.delegation_responses' >> "$temp_json_file"; next_key=$(echo "$response" | jq -r '.pagination.next_key')
        if [[ $page_num -eq 1 ]]; then total_delegators=$(echo "$response" | jq -r '.pagination.total'); if [[ "$total_delegators" -gt 0 ]]; then total_pages=$(( (total_delegators + page_size - 1) / page_size )); fi; fi; ((page_num++)); sleep 1
    done
    echo "Все страницы получены. Конвертация в CSV..." >&2
    jq -r -s 'add | .[] | [.delegation.delegator_address, .balance.amount] | @csv' "$temp_json_file" > "$output_file"
    rm "$temp_json_file"; echo "✅ Снапшот успешно создан: $output_file" >&2; return 0
}

# --- Фаза 6: Расчет компенсации ---
calculate_compensation() {
    local FILE_BEFORE="snapshot_${SNAPSHOT_BLOCK_BEFORE}.csv"; local FILE_AFTER="snapshot_${SNAPSHOT_BLOCK_JAIL}.csv"
    if [ ! -f "$FILE_BEFORE" ] || [ ! -f "$FILE_AFTER" ]; then echo "Ошибка: Один из файлов-снапшотов не найден! Расчет невозможен." >&2; return 1; fi
    local ADD_EXTRA_COMPENSATION=false; local EXTRA_PERCENTAGE=25
    echo ""; echo "--- Фаза 6: Настройка и расчет компенсации ---"; echo "========================================================"
    echo "Опция: Добавить дополнительную компенсацию сверх потерь?"; echo "Текущие настройки:"; echo "  - Дополнительная компенсация: ВЫКЛЮЧЕНА"
    echo "========================================================"; read -p "Хотите включить доп. компенсацию? (y/n, по умолчанию 'n'): " enable_extra
    if [[ "$enable_extra" == "y" || "$enable_extra" == "Y" ]]; then
        ADD_EXTRA_COMPENSATION=true; read -p "Введите процент дополнительной компенсации (например, 25): " new_percentage
        if [[ "$new_percentage" =~ ^[0-9]+$ ]]; then EXTRA_PERCENTAGE=$new_percentage; else echo "Некорректный ввод. Используется значение по умолчанию: 25%"; EXTRA_PERCENTAGE=25; fi
    fi
    local COMPENSATION_MULTIPLIER=1; local OUTPUT_FILE="compensation_amounts.csv"
    if [ "$ADD_EXTRA_COMPENSATION" = true ]; then OUTPUT_FILE="compensation_amounts_${EXTRA_PERCENTAGE}_pc.csv"; COMPENSATION_MULTIPLIER=$(echo "1 + $EXTRA_PERCENTAGE / 100" | bc -l); fi
    echo "---------------------------------"; echo "Начинаю сравнение файлов:"; echo "ДО:    $FILE_BEFORE"; echo "ПОСЛЕ: $FILE_AFTER"
    if [ "$ADD_EXTRA_COMPENSATION" = true ]; then echo "ОПЦИЯ: Компенсация будет умножена на $COMPENSATION_MULTIPLIER (+$EXTRA_PERCENTAGE%)."; else echo "ОПЦИЯ: Расчет компенсации 1-в-1."; fi
    echo "Итоговый файл будет назван: $OUTPUT_FILE"; echo "---------------------------------"
    awk -v multiplier="$COMPENSATION_MULTIPLIER" '
    BEGIN { FS=OFS="," } FNR==NR { gsub(/"/, "", $1); gsub(/"/, "", $2); before[$1] = $2; next }
    { gsub(/"/, "", $1); gsub(/"/, "", $2); loss = before[$1] - $2; compensation = 0; if (loss > 0) { compensation = loss * multiplier; } printf "%s,%.0f\n", $1, compensation; delete before[$1] }
    END { for (addr in before) { loss = before[addr]; compensation = loss * multiplier; printf "%s,%.0f\n", addr, compensation; } }' "$FILE_BEFORE" "$FILE_AFTER" > "$OUTPUT_FILE"
    echo "✅ Расчет завершен."; echo "Итоговый файл с суммами для компенсации создан: $OUTPUT_FILE"; return 0
}


# --- Фаза 7: Основной блок выполнения ---
main() {
    local -a rpc_to_use
    if [[ -n "$NODE" ]]; then
        echo "--- Используется RPC-узел, указанный в файле конфигурации: $NODE ---"
        rpc_to_use=("$NODE")
    else
        read -r -a rpc_to_use <<< "$(test_rpc_list "$START_BLOCK" "${PUBLIC_RPCS[@]}")"
        if [ ${#rpc_to_use[@]} -eq 0 ]; then exit 1; fi
        echo "Найдено ${#rpc_to_use[@]} подходящих RPC-узлов. Они будут использоваться по очереди."
    fi
    echo "---------------------------------------------------------"

    run_jail_search "${rpc_to_use[@]}"
    if [[ $? -ne 0 ]]; then exit 1; fi
    echo "---------------------------------------------------------"
    read -p "Блоки для снапшотов определены. Нажмите Enter, чтобы начать их создание..."
    echo ""

    WORKING_API=$(find_and_test_api)
    if [[ $? -ne 0 ]]; then exit 1; fi
    echo "---------------------------------------------------------"

    create_single_snapshot "$SNAPSHOT_BLOCK_BEFORE" "$WORKING_API"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    create_single_snapshot "$SNAPSHOT_BLOCK_JAIL" "$WORKING_API"
    if [[ $? -ne 0 ]]; then exit 1; fi
    
    echo ""; echo "========================================================="
    echo "ГОТОВО! Оба снапшота успешно созданы."
    echo "========================================================="

    calculate_compensation
}

# Запуск основной функции
main
