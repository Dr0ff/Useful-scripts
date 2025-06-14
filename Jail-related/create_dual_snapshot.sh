#!/bin/bash

# --- Конфигурация ---
VALIDATOR="junovaloper1tx2u0nvjwregdv6a5t5k7z0krv6l8l6hgq4z85"

# Блок ДО попадания в тюрьму (N-1)
SNAPSHOT_BLOCK_BEFORE="27339152"

# Блок ПОСЛЕ (блок выхода из тюрьмы)
SNAPSHOT_BLOCK_AFTER="27342729"
# -------------------

# Проверка на наличие утилит jq и curl
if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    echo "Ошибка: отсутствуют необходимые утилиты jq или curl." >&2
    exit 1
fi

# --- Фаза 1: Автоматический поиск и проверка рабочего API ---
find_and_test_api() {
    echo "--- ФАЗА 1: Поиск рабочего API-узла ---" >&2
    echo "Загружаю список API-узлов из Cosmos Chain Registry..." >&2
    
    local api_list_json=$(curl -sL https://raw.githubusercontent.com/cosmos/chain-registry/master/juno/chain.json)
    mapfile -t api_urls < <(echo "$api_list_json" | jq -r '.apis.rest[].address')

    if [ ${#api_urls[@]} -eq 0 ]; then
        echo "Не удалось получить список API-узлов." >&2
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

# --- Фаза 2: Функция для создания одного снапшота ---
create_single_snapshot() {
    local snapshot_block=$1
    local api_endpoint=$2
    local page_size=200
    local output_file="snapshot_${snapshot_block}.csv" # Имя файла изменено на .csv
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
    
    # --- ИЗМЕНЕННАЯ СТРОКА С ВОЗВРАЩЕНИЕМ К CSV ---
    jq -r -s 'add | .[] | [.delegation.delegator_address, .balance.amount] | @csv' "$temp_json_file" > "$output_file"
    
    rm "$temp_json_file"
    echo "✅ Снапшот успешно создан: $output_file" >&2
    return 0
}

# --- Основной блок скрипта ---
WORKING_API=$(find_and_test_api)

if [[ $? -eq 0 ]]; then
    # --- Создаем первый снапшот (ДО) ---
    create_single_snapshot "$SNAPSHOT_BLOCK_BEFORE" "$WORKING_API"
    
    # --- Создаем второй снапшот (ПОСЛЕ) ---
    create_single_snapshot "$SNAPSHOT_BLOCK_AFTER" "$WORKING_API"
    
    echo "---------------------------------------------------------"
    echo "Готово! Оба снапшота созданы."
else
    echo "Не удалось продолжить, так как не был найден рабочий API-узел." >&2
    exit 1
fi
