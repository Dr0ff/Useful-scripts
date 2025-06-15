#!/bin/bash
# ЦЕЛЬ: Найти точный блок входа в тюрьму, используя блок выхода (unjail) для определения конца поиска.

# --- Сбор данных для поиска ---
echo "--- Поиск блока входа в тюрьму ---"
echo "Пожалуйста, введите необходимые данные:"
echo "--------------------------------------------------------------------"

# Основные данные
read -p "1. Адрес RPC ноды: " NODE
read -p "2. Valoper адрес валидатора: " VALIDATOR
read -p "3. Имя демона (daemon) (например: junod): " DAEMON
echo ""

# Запрашиваем два ключевых блока, из которых будет рассчитан диапазон.
echo "--- Укажите 2 ключевых блока ---"
read -p "4. Начальный блок (когда валидатор был еще ВНЕ тюрьмы): " START_BLOCK
read -p "5. Блок, в котором прошла транзакция UNJAIL: " UNJAIL_TX_BLOCK
echo ""

# --- Автоматический расчет и подтверждение ---

# Конечный блок для поиска - это блок прямо перед выходом из тюрьмы.
# На этом блоке валидатор гарантированно был в статусе 'jailed: true'.
END_BLOCK=$((UNJAIL_TX_BLOCK - 1))

echo "--- Пожалуйста, проверьте данные ---"
echo "RPC Нода:                  $NODE"
echo "Адрес валидатора:          $VALIDATOR"
echo "Демон (Daemon):            $DAEMON"
echo ""
echo "На основе ваших данных, поиск будет выполнен в диапазоне:"
echo "Начало поиска: $START_BLOCK"
echo "Конец поиска:  $END_BLOCK (Рассчитан как 'Блок Unjail - 1')"
echo "---------------------------------------------------------"
read -p "Все верно? Нажмите Enter для начала поиска..."
echo ""

# --- Поиск точки ВХОДА в тюрьму (Бинарный поиск) ---

# Функция для запроса статуса
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

# Копируем переменные, чтобы не изменять оригиналы
SEARCH_START_BLOCK=$START_BLOCK
SEARCH_END_BLOCK=$END_BLOCK
JAIL_BLOCK=0

echo "--- Запуск поиска... ---"
while [[ $SEARCH_START_BLOCK -le $SEARCH_END_BLOCK ]]; do
    MID_BLOCK=$((SEARCH_START_BLOCK + (SEARCH_END_BLOCK - SEARCH_START_BLOCK) / 2))
    # Проверка, чтобы не выйти за пределы исходного диапазона
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

# --- Вывод финального результата ---
if [[ $JAIL_BLOCK -ne 0 ]]; then
    echo "Верификация найденного блока..."
    BLOCK_N=$JAIL_BLOCK; BLOCK_N_MINUS_1=$((JAIL_BLOCK - 1))
    STATUS_N_MINUS_1=$(query_with_retry "$BLOCK_N_MINUS_1"); STATUS_N=$(query_with_retry "$BLOCK_N")
    
    echo ""
    echo "==================== РЕЗУЛЬТАТ ПОИСКА ===================="
    if [[ "$STATUS_N" == "true" && "$STATUS_N_MINUS_1" == "false" ]]; then
        echo "✅ Переход в тюрьму подтвержден."
        echo "Блок до тюрьмы:        $BLOCK_N_MINUS_1"
        echo "Первый блок в тюрьме:  $BLOCK_N"
    else
        echo "❌ ЛОГИЧЕСКАЯ ОШИБКА!"
        echo "Не удалось точно определить переход. Проверьте исходный диапазон."
        echo "Статус на блоке $BLOCK_N_MINUS_1: $STATUS_N_MINUS_1"
        echo "Статус на блоке $BLOCK_N:         $STATUS_N"
    fi
    echo "==========================================================="

else
    echo "==================== РЕЗУЛЬТАТ ПОИСКА ===================="
    echo "❌ Не удалось найти блок, где валидатор был в тюрьме, в заданном диапазоне."
    echo "==========================================================="
fi

