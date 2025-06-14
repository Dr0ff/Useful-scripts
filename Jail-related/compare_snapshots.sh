#!/bin/bash

# --- КОНФИГУРАЦИЯ ---
# Имя файла со снапшотом "ДО"
FILE_BEFORE="snapshot_27339152.csv"

# Имя файла со снапшотом "ПОСЛЕ"
FILE_AFTER="snapshot_27342729.csv"

# Имя итогового файла с результатами
OUTPUT_FILE="compensation_amounts.csv"
# --------------------


# Проверка, существуют ли входные файлы, чтобы избежать ошибок
if [ ! -f "$FILE_BEFORE" ]; then
    echo "Ошибка: Файл 'ДО' не найден: $FILE_BEFORE"
    exit 1
fi

if [ ! -f "$FILE_AFTER" ]; then
    echo "Ошибка: Файл 'ПОСЛЕ' не найден: $FILE_AFTER"
    exit 1
fi

echo "Начинаю сравнение файлов:"
echo "ДО:   $FILE_BEFORE"
echo "ПОСЛЕ: $FILE_AFTER"
echo "---------------------------------"

# Та самая команда AWK, которую мы отладили
awk '
BEGIN { 
    FS=OFS="," # Устанавливаем запятую как разделитель
    print "delegator_address,compensation_amount_ujuno" # Добавляем заголовок в итоговый файл
}
FNR==NR {
    # Убираем кавычки и запоминаем балансы "ДО"
    gsub(/"/, "", $1); 
    gsub(/"/, "", $2);
    before[$1] = $2;
    next
}
{
    # Убираем кавычки из полей файла "ПОСЛЕ"
    gsub(/"/, "", $1); 
    gsub(/"/, "", $2);
    
    # Рассчитываем потерю
    loss = before[$1] - $2;
    
    # Если потеря есть (loss > 0), печатаем ее. Иначе печатаем 0.
    if (loss > 0) {
        print $1, loss;
    } else {
        print $1, 0;
    }
    
    # Удаляем адрес из памяти, чтобы в конце остались только те, кто ушел полностью
    delete before[$1]
}
END {
    # Для тех, кто ушел полностью, их потеря равна всему их стейку "ДО"
    for (addr in before) {
        print addr, before[addr]
    }
}
' "$FILE_BEFORE" "$FILE_AFTER" > "$OUTPUT_FILE"

echo "✅ Сравнение завершено."
echo "Итоговый файл с суммами для компенсации создан: $OUTPUT_FILE"
