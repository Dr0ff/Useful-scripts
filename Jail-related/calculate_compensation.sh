#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
# Имя файла со снапшотом "ДО"
FILE_BEFORE="snapshot_27339152.csv"

# Имя файла со снапшотом "ПОСЛЕ"
FILE_AFTER="snapshot_27342729.csv"

# Имя итогового файла с результатами
OUTPUT_FILE="compensation_amounts.csv"

# --- НОВАЯ ОПЦИЯ: Дополнительная компенсация ---
# Установите 'true', чтобы добавить процент сверху, или 'false', чтобы отключить.
ADD_EXTRA_COMPENSATION=true

# Какой процент добавить, если опция выше включена (например, 25 для 25%)
EXTRA_PERCENTAGE=25
# --------------------


# Проверка, существуют ли входные файлы
if [ ! -f "$FILE_BEFORE" ] || [ ! -f "$FILE_AFTER" ]; then
    echo "Ошибка: Один из файлов-снапшотов не найден!"
    exit 1
fi

echo "Начинаю сравнение файлов:"
echo "ДО:   $FILE_BEFORE"
echo "ПОСЛЕ: $FILE_AFTER"

if [ "$ADD_EXTRA_COMPENSATION" = true ]; then
    echo "ОПЦИЯ: Добавляю $EXTRA_PERCENTAGE% к сумме компенсации."
else
    echo "ОПЦИЯ: Расчет компенсации без дополнительных процентов."
fi

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
