#!/bin/bash

while true; do
    # Запрашиваем данные
    read -p "Enter your node Binary name (eg: junod, lavad, xplad): " binary
    read -p "Enter your node Network or directory name (eg: juno, lava, sommelier): " network
    
    # Выводим данные для проверки
    echo " "
    echo -e "Your node's Binary file name: \e[33m$binary\e[0m"
    echo -e "Your node's Network/Directory name: \e[33m$network \e[0m"
    echo " "
    
    # Спрашиваем пользователя, всё ли верно
    read -p "All good? Yes/No: " answer
    case $answer in
        [Yy]*)
            break  # Прерывает цикл и продолжает выполнение
            ;;
        [Nn]*)
            echo "Let's try again."
            # Цикл продолжится, данные будут запрашиваться заново
            ;;
        *)
            echo "Please answer 'Yes' or 'No'."
            # Цикл продолжится, если введено что-то другое
            ;;
    esac
done
sudo -v
block=$($binary status | jq -r '.SyncInfo.latest_block_height')
snap_file=~/"${network}_snap_$(date +%Y-%m-%d)_$block.tar.lz4"
echo -e "Your snapshot will be saved to: \n\e[33m$snap_file\e[0m"
echo -e "To unpack your snapshot use:\n\e[33mlz4 -c -d $snap_file | tar -x -C ~/.$network\e[0m"
exit 1
# Останавливаем ноду
sudo systemctl stop $network.service

# Создаём снапшот, сохраняя только `data/`
tar -cf - -C ~/.$network data | lz4 -9 > $snap_file

# Запускаем ноду
sudo systemctl start $network.service
echo -e "We restarting your $network node again. \n To check it just run folowing: \e\[33msudo journalctl -u $network -f --output cat\e[0m "
