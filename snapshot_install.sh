#!/bin/bash

bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

echo -e "\n\e[37m  -----------------------------------------------------------------------------------------\e[0m"
echo -e "\e[93m    Этот скрипт производит очистку ноды и переустанавливает базу данных сети из снапшота!\e[0m"
echo -e "\e[37m  -----------------------------------------------------------------------------------------\n\e[0m"

echo -e "\n\e[93m                                --- Настройки ---\e[0m"

echo -e "\n\e[93m Как называется ваша сеть? (пример: sentinel, stargaze, etc...)\n\e[0m"
read -p "Введите имя сети: " NAME
echo -e "\n\e[93m В какой директории находится нода? (.sentinelhub, .starsd, etc...)\n\e[0m"
read -p "Введите название (без точки): " DIR
echo -e "\n\e[93m Как называется DAEMON (бинарник)  (пример: junod, starsd, sentinelhub...)\n\e[0m"
read -p "Введите имя бинарника: " BIN

echo -e "\n\e[93m Для продолжения нажмите любую клавишу\e[0m"
echo -e "\e[91m Или CTRL+C, для прерывания процесса\e[0m"
read -p " "

#NAME=juno
#DIR=juno
#BIN=junod

echo -e "\n\e[93m                           --- Получение снапшота ---\e[0m"

# echo -e "\n\e[93m Ссылку на снапшот можно взять на сайте \e[33m https://polkachu.com/tendermint_snapshots/${NAME}\e[0m"
echo -e "\n\e[93m  ⚠️   Перейдите на сайт: \e[97m https://polkachu.com/tendermint_snapshots/${NAME}\e[0m"
echo -e "\e[93m       Найдите снапшот!\e[0m"
echo -e "\e[33m Правый клик на ссылке для загрузки файла и там выбрать\e[37m \"Копировать адрес ссылки\"\n\e[0m"
read -p "Вставьте ссылку на снапшот: " SNAP_LINK
echo -e "\n\e[93m Для продолжения нажмите любую клавишу \e[0m"
read -p ""

echo -e "\n\e[93m                           --- Скачиваю снапшот ---\n\e[0m"

wget -O ${NAME}_latest.tar.lz4 $SNAP_LINK --inet4-only

if [ $? -ne 0 ]; then
    echo -e "\n\e[91mОШИБКА: Не удалось скачать снапшот!\e[0m"
    echo -e "\e[93mПожалуйста, проверьте правильность ссылки и ваше интернет-соединение.\e[0m"
    echo -e "\e[93mПрерываю выполнение скрипта.\e[0m"
    exit 1
fi

echo -e "\n\e[93m                               --- Установка ---\e[0m"
echo -e "\n\e[93m Возможно потребуется пароль SUDO \n\e[0m"

sudo -v

wget -O ${NAME}_latest.tar.lz4 $SNAP_LINK --inet4-only
sudo systemctl stop ${NAME}.service
cp $HOME/.$DIR/data/priv_validator_state.json $HOME/.$DIR/priv_validator_state.json.backup
$BIN tendermint unsafe-reset-all --home $HOME/.$DIR --keep-addr-book
rm -r ~/.$DIR/wasm
lz4 -c -d ${NAME}_latest.tar.lz4  | tar -x -C $HOME/.$DIR
mv $HOME/.$DIR/priv_validator_state.json.backup $HOME/.$DIR/data/priv_validator_state.json
sudo systemctl start ${NAME}.service
rm -v ${NAME}_latest.tar.lz4
sudo journalctl -u $NAME -f --output cat
