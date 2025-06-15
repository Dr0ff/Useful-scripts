#!/bin/bash
# ЦЕЛЬ: Полностью автоматизировать процесс создания снапшотов для компенсации.
# 1. Найти точный блок входа в тюрьму.
# 2. Найти рабочий API-узел.
# 3. Сделать два снапшота: на блоке ДО тюрьмы и на ПЕРВОМ блоке В тюрьме.

# --- Предварительная проверка ---
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    echo "Ошибка: отсутствуют необходимые утилиты jq или curl." >&2
    exit 1
fi

# --- Фаза 1: Сбор всех необходимых данных ---
echo "--- Фаза 1: Сбор данных ---"
echo "Пожалуйста, введите необходимые данные:"
echo "--------------------------------------------------------------------"

# Основные данные
read -p "1. Адрес RPC ноды: " NODE
read -p "2. Valoper адрес валидатора: " VALIDATOR
read -p "3. Имя демона (daemon) (например: junod): " DAEMON
read -p "4. Имя сети в Chain Registry (например: juno): " CHAIN_NAME
echo ""

# Блоки для поиска
echo "--- Укажите диапазон, внутри которого произошел ВХОД в тюрьму ---"
read -p "5. Начальный блок (когда валидатор был еще ВНЕ тюрьмы): " START_BLOCK
read -p "6. Конечный блок (когда валидатор был УЖЕ В тюрьме): " END_BLOCK
echo ""

# --- Подтверждение ---
echo "--- Пожалуйста, проверьте данные ---"
echo "RPC Нода:                  $NODE"
echo "Адрес валидатора:          $VALIDATOR"
echo "Демон (Daemon):            $DAEMON"
echo "Имя сети:                  $CHAIN_NAME"
echo "Диапазон поиска:           с $START_BLOCK по $END_BLOCK"
echo "---------------------------------------------------------"
read -p "Все верно? Нажмите Enter для начала работы..."
echo ""


# --- Фаза 2: Поиск точки ВХОДА в тюрьму ---

# Функция для запроса статуса через RPC
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

# Копируем переменные для поиска
SEARCH_START_BLOCK=$START_BLOCK
SEARCH_END_BLOCK=$END_BLOCK
JAIL_BLOCK=0

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

# --- Определение блоков для снапшотов ---
SNAPSHOT_BLOCK_BEFORE=0
SNAPSHOT_BLOCK_JAIL=0

if [[ $JAIL_BLOCK -ne 0 ]]; then
    BLOCK_N=$JAIL_BLOCK
    BLOCK_N_MINUS_1=$((JAIL_BLOCK - 1))
    STATUS_N_MINUS_1=$(query_with_retry "$BLOCK_N_MINUS_1")
    STATUS_N=$(query_with_retry "$BLOCK_N")
    
    if [[ "$STATUS_N" == "true" && "$STATUS_N_MINUS_1" == "false" ]]; then
        echo "✅ Переход в тюрьму подтвержден."
        SNAPSHOT_BLOCK_BEFORE=$BLOCK_N_MINUS_1
        SNAPSHOT_BLOCK_JAIL=$BLOCK_N
        echo "Блок для первого снапшота (до тюрьмы): $SNAPSHOT_BLOCK_BEFORE"
        echo "Блок для второго снапшота (в тюрьме): $SNAPSHOT_BLOCK_JAIL"
    else
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось точно определить переход. Проверьте исходный диапазон." >&2
        exit 1
    fi
else
    echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось найти блок входа в тюрьму в заданном диапазоне." >&2
    exit 1
fi
echo "---------------------------------------------------------"
read -p "Блоки для снапшотов определены. Нажмите Enter, чтобы начать их создание..."
echo ""

# --- Фаза 3: Поиск рабочего API ---
find_and_test_api() {
    echo "--- Фаза 3: Поиск рабочего API-узла для сети '$CHAIN_NAME' ---" >&2
    echo "Загружаю список API-узлов из Cosmos Chain Registry..." >&2
    
    local registry_url="https://raw.githubusercontent.com/cosmos/chain-registry/master/${CHAIN_NAME}/chain.json"
    local api_list_json=$(curl -sL "$registry_url")
    mapfile -t api_urls < <(echo "$api_list_json" | jq -r '.apis.rest[].address')

    if [ ${#api_urls[@]} -eq 0 ]; then
        echo "Не удалось получить список API-узлов для сети '$CHAIN_NAME'." >&2
        return 1
    fi

    echo "Найдено ${#api_urls[@]} API-узлов. Начинаю проверку..." >&2
    echo "---------------------------------------------------------" >&2

    for url in "${api_urls[@]}"; do
        url=$(echo "$url" | sed 's:/*$::') 
        echo -n "Проверяю $url ... " >&2
        
        local health_check_url="${url}/cosmos/base/tendermint/v1beta1/node_info"
        local http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -m 10 "$health_check_url")

        if [[ "$http_code" -eq 200 ]]; then
            echo "✅ Работает!" >&2
            echo "$url"
            return 0
        else
            echo "❌ Не отвечает (код: $http_code)." >&2
        fi
    done
    
    echo "КРИТИЧЕСКАЯ ОШИБКА: Не найдено ни одного рабочего API-узла." >&2
    return 1
}

# --- Фаза 4: Функция для создания одного снапшота ---
create_single_snapshot() {
    local snapshot_block=$1
    local api_endpoint=$2
    local page_size=200
    local output_file="snapshot_${snapshot_block}.csv"
    local temp_json_file=$(mktemp)
    
    echo "---------------------------------------------------------" >&2
    echo "--- Создание снапшота на блоке $snapshot_block ---" >&2
    echo "--- (Использую проверенный API: $api_endpoint) ---" >&2

    local next_key="initial"; local page_num=1
    while [[ -n "$next_key" && "$next_key" != "null" ]]; do
        local total_pages_info=""
        if [[ -n "$total_delegators" ]]; then
            total_pages_info=" из ~$total_pages"
        fi
        echo "Запрос страницы $page_num$total_pages_info..." >&2
        
        local pagination_param=""
        if [[ "$next_key" != "initial" ]]; then
            local encoded_key=$(printf %s "$next_key" | jq -s -R -r @uri)
            pagination_param="&pagination.key=$encoded_key"
        fi
        
        local URL="${api_endpoint}/cosmos/staking/v1beta1/validators/${VALIDATOR}/delegations?pagination.limit=${page_size}${pagination_param}"
        
        local attempt=1; local max_retries=15; local response=""
        while [[ $attempt -le $max_retries ]]; do
            response=$(curl --silent -m 60 -H "x-cosmos-block-height: $snapshot_block" -X GET "$URL")
            if echo "$response" | jq -e '.delegation_responses' > /dev/null; then break; fi
            echo "Попытка $attempt/$max_retries не удалась для страницы $page_num. Повтор через 5с..." >&2
            sleep 5; ((attempt++))
        done

        if ! echo "$response" | jq -e '.delegation_responses' > /dev/null; then
            echo "КРИТИЧЕСКАЯ ОШИБКА: Не удалось получить данные о делегаторах после $max_retries попыток." >&2
            rm "$temp_json_file"; return 1
        fi

        echo "$response" | jq '.delegation_responses' >> "$temp_json_file"
        next_key=$(echo "$response" | jq -r '.pagination.next_key')
        
        if [[ $page_num -eq 1 ]]; then
            total_delegators=$(echo "$response" | jq -r '.pagination.total')
            if [[ "$total_delegators" -gt 0 ]]; then
                total_pages=$(( (total_delegators + page_size - 1) / page_size ))
            fi
        fi
        ((page_num++)); sleep 1
    done

    echo "Все страницы получены. Конвертация в CSV..." >&2
    
    jq -r -s 'add | .[] | [.delegation.delegator_address, .balance.amount] | @csv' "$temp_json_file" > "$output_file"
    
    rm "$temp_json_file"
    echo "✅ Снапшот успешно создан: $output_file" >&2
    return 0
}

# --- Фаза 5: Основной блок выполнения ---
WORKING_API=$(find_and_test_api)

if [[ $? -eq 0 ]]; then
    # --- Создаем первый снапшот (ДО) ---
    create_single_snapshot "$SNAPSHOT_BLOCK_BEFORE" "$WORKING_API"
    
    # --- Создаем второй снапшот (В ТЮРЬМЕ) ---
    create_single_snapshot "$SNAPSHOT_BLOCK_JAIL" "$WORKING_API"
    
    echo ""
    echo "========================================================="
    echo "ГОТОВО! Оба снапшота успешно созданы."
    echo "========================================================="
else
    echo "Не удалось продолжить, так как не был найден рабочий API-узел." >&2
    exit 1
fi
