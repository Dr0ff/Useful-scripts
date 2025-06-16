#!/bin/bash

bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

echo -e "\n\e[37m -------------------------------------------------------------------------------------\e[0m"
echo -e "\e[93m Этот скрипт производит очистку ноды и переустанавливает базу данных сети из снапшота!\e[0m"
echo -e "\e[37m -------------------------------------------------------------------------------------\e[0m"

echo -e "\n\e[93m Введите Имя Сети (пример: sentinel, stargaze) : \e[0m"
read -p " " NAME
echo -e "\n\e[93m Введите название директории ноды (без точки перед именем) : \e[0m"
read -p " " DIR
echo -e "\n\e[93m Введите имя бинарника (пример: junod, starsd sentinelhub...) : \e[0m"
read -p " " BIN

echo -e "\n\e[92m Нажмите любую клавишу, чтобы продолжить\e[0m"
echo -e "\e[91m Или CTRL+C, чтобы прервать процесс\e[0m"
read -p " "

#NAME=juno
#DIR=juno
#BIN=junod

sudo -v
echo -e "\n\e[92m Ссылку на снапшот можно взять на сайте \e[33m https://polkachu.com/tendermint_snapshots/${NAME}\e[0m"
echo -e "\n\e[93m  ⚠️   Перейдите на сайт, найдите снапшот!\e[0m"
echo -e "\e[92m Правый клик на файле для загрузки и там выбрать\e[33m \"Копировать адрес ссылки\"\e[0m"
read -p "Вставьте сюда ссылку на снапшот: " SNAP_LINK
echo -e "\n\e[93m Для продолжения нажмите любую клавишу \e[0m"
read -p ""

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
