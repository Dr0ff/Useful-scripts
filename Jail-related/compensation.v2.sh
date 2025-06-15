#!/bin/bash

# --- КОНФИГУРАЦИЯ ПО УМОЛЧАНИЮ ---
# Имя файла со снапшотом "ДО"
FILE_BEFORE="snapshot_27339152.csv"

# Имя файла со снапшотом "ПОСЛЕ"
FILE_AFTER="snapshot_27342729.csv"

# --- ОПЦИЯ: Дополнительная компенсация (значения по умолчанию) ---
ADD_EXTRA_COMPENSATION=true
EXTRA_PERCENTAGE=25
# --------------------

# --- ИНТЕРАКТИВНЫЙ БЛОК НАСТРОЙКИ ---
echo "========================================================"
echo "Текущие настройки экстра-компенсации:"

if [ "$ADD_EXTRA_COMPENSATION" = true ]; then
    echo "  - Дополнительная компенсация: ВКЛЮЧЕНА"
    echo "  - Процент: $EXTRA_PERCENTAGE%"
else
    echo "  - Дополнительная компенсация: ВЫКЛЮЧЕНА"
fi
echo "========================================================"

read -p "Продолжить с этими настройками? (y/n, по умолчанию 'y'): " confirm

# Если пользователь ввел что-то кроме 'y' или 'Y' (или просто нажал Enter), считаем, что он хочет внести изменения.
if [[ "$confirm" != "y" && "$confirm" != "Y" && -n "$confirm" ]]; then
    echo "---------------------------------"
    echo "--- Настройка опций ---"
    read -p "Включить дополнительную компенсацию? (y/n): " enable_extra

    if [[ "$enable_extra" == "y" || "$enable_extra" == "Y" ]]; then
        ADD_EXTRA_COMPENSATION=true
        read -p "Введите процент дополнительной компенсации (например, 25): " new_percentage
        # Простая проверка, что введено целое положительное число
        if [[ "$new_percentage" =~ ^[0-9]+$ ]]; then
            EXTRA_PERCENTAGE=$new_percentage
        else
            echo "Некорректный ввод. Используется значение по умолчанию: 25%"
            EXTRA_PERCENTAGE=25
        fi
    else
        ADD_EXTRA_COMPENSATION=false
        EXTRA_PERCENTAGE=0 # Если опция выключена, процент не имеет значения
    fi
    echo "Настройки обновлены."
fi
# --- КОНЕЦ ИНТЕРАКТИВНОГО БЛОКА ---


# --- Динамическое формирование имени выходного файла ---
if [ "$ADD_EXTRA_COMPENSATION" = true ]; then
    OUTPUT_FILE="compensation_amounts_${EXTRA_PERCENTAGE}_pc.csv"
else
    OUTPUT_FILE="compensation_amounts.csv"
fi


# Проверка, существуют ли входные файлы
if [ ! -f "$FILE_BEFORE" ] || [ ! -f "$FILE_AFTER" ]; then
    echo "Ошибка: Один из файлов-снапшотов не найден!"
    exit 1
fi

echo "---------------------------------"
echo "Начинаю сравнение файлов:"
echo "ДО:   $FILE_BEFORE"
echo "ПОСЛЕ: $FILE_AFTER"

if [ "$ADD_EXTRA_COMPENSATION" = true ]; then
    echo "ОПЦИЯ: Добавляю $EXTRA_PERCENTAGE% к сумме компенсации."
else
    echo "ОПЦИЯ: Расчет компенсации без дополнительных процентов."
fi

echo "Итоговый файл будет назван: $OUTPUT_FILE"
echo "---------------------------------"

# Передаем настройки из Bash в AWK с помощью флага -v
awk -v add_extra="$ADD_EXTRA_COMPENSATION" -v extra_pct="$EXTRA_PERCENTAGE" '
BEGIN { 
    FS=OFS=","
    print "delegator_address,compensation_amount_ujuno"
}
FNR==NR {
    gsub(/"/, "", $1); 
    gsub(/"/, "", $2);
    before[$1] = $2;
    next
}
{
    gsub(/"/, "", $1); 
    gsub(/"/, "", $2);
    
    loss = before[$1] - $2;
    
    # Рассчитываем итоговую сумму для компенсации
    compensation = 0; # По умолчанию компенсация равна 0
    if (loss > 0) {
        if (add_extra == "true") {
            # Рассчитываем потерю + процент
            compensation = loss * (1 + (extra_pct / 100));
        } else {
            # Просто потеря без доплаты
            compensation = loss;
        }
    }
    
    # Печатаем адрес и итоговую сумму, округленную до целого числа
    printf "%s,%.0f\n", $1, compensation;
    
    delete before[$1]
}
END {
    # Обрабатываем тех, кто полностью вывел стейк
    for (addr in before) {
        loss = before[addr];
        compensation = 0;
        if (add_extra == "true") {
            compensation = loss * (1 + (extra_pct / 100));
        } else {
            compensation = loss;
        }
        printf "%s,%.0f\n", addr, compensation;
    }
}
' "$FILE_BEFORE" "$FILE_AFTER" > "$OUTPUT_FILE"

echo "✅ Сравнение завершено."
echo "Итоговый файл с суммами для компенсации создан: $OUTPUT_FILE"
