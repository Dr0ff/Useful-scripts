import csv

# --- КОНФИГУРАЦИЯ ---

# Файл со снапшотом ДО попадания в тюрьму
SNAPSHOT_FILE_BEFORE = 'snapshot_27339152.csv'

# Годовая процентная ставка (APR) для JUNO. 
# Укажите актуальное значение. Например, 15% - это 0.15.
# Это значение можно найти на сайтах для стейкинга или в эксплорерах.
JUNO_APR = 0.15 

# Данные о времени простоя
JAILED_BLOCK = 27339153
UNJAILED_BLOCK = 27342729
AVG_BLOCK_TIME_SEC = 2.74 # Рассчитано нами ранее

# Имя итогового файла
COMPENSATION_FILE = 'compensation_payout_list.csv'

# --- РАСЧЕТЫ ---

def calculate_and_save_compensation():
    # Расчет длительности простоя в днях
    blocks_jailed = UNJAILED_BLOCK - JAILED_BLOCK
    seconds_jailed = blocks_jailed * AVG_BLOCK_TIME_SEC
    days_jailed = seconds_jailed / (60 * 60 * 24)

    print("--- Расчет компенсации за упущенные награды ---")
    print(f"Длительность простоя: {blocks_jailed} блоков (~{days_jailed:.3f} дней)")
    print(f"Используемый APR: {JUNO_APR * 100:.2f}%")
    print("--------------------------------------------------")

    # Читаем снапшот и рассчитываем компенсацию
    try:
        with open(SNAPSHOT_FILE_BEFORE, 'r') as infile, open(COMPENSATION_FILE, 'w', newline='') as outfile:
            reader = csv.reader(infile)
            writer = csv.writer(outfile)

            # Записываем заголовок в итоговый файл
            writer.writerow(['delegator_address', 'staked_amount_ujuno', 'compensation_amount_ujuno'])

            for row in reader:
                address, amount_staked_str = row
                amount_staked = int(amount_staked_str)
                
                # Формула расчета упущенных наград
                # (сумма стейка * дневной процент) * кол-во дней
                daily_apr = JUNO_APR / 365
                compensation = amount_staked * daily_apr * days_jailed
                
                # Записываем результат
                writer.writerow([address, amount_staked, int(compensation)])

        print(f"✅ Расчет завершен. Список выплат сохранен в файл: {COMPENSATION_FILE}")

    except FileNotFoundError:
        print(f"ОШИБКА: Файл снапшота '{SNAPSHOT_FILE_BEFORE}' не найден. Убедитесь, что он находится в той же папке.")
    except Exception as e:
        print(f"Произошла непредвиденная ошибка: {e}")

# Запуск функции
if __name__ == "__main__":
    calculate_and_save_compensation()
