#!/bin/bash

bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

sudo -v
echo -e "\n\e[33m Этот скрипт производит очистку ноды и переустанавливает базу данных сети из снапшота!\e[0m"
echo -e "\n\e[32m Ссылку на снапшот можно взять на сайте \e[34m https://polkachu.com/tendermint_snapshots/juno\e[0m"
echo -e "\e[32m Правый клик на файле для загрузки и там выбрать\e[33m \"Скопировать адрес\"\e[0m"
read -p "Вставьте сюда ссылку на снапшот: " SNAP_LINK
echo -e "\n\e[33m Для продолжения нажмите любую клавишу \e[0m"
read -p ""
wget -O juno_latest.tar.lz4 $SNAP_LINK --inet4-only
sudo systemctl stop juno.service
cp $HOME/.juno/data/priv_validator_state.json $HOME/.juno/priv_validator_state.json.backup
junod tendermint unsafe-reset-all --home $HOME/.juno --keep-addr-book
lz4 -c -d juno_latest.tar.lz4  | tar -x -C $HOME/.juno
mv $HOME/.juno/priv_validator_state.json.backup $HOME/.juno/data/priv_validator_state.json
sudo systemctl start juno.service
sudo journalctl -u juno -f --output cat
rm -v juno_latest.tar.lz4

#!/bin/bash

bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

read -p "Введите Имя Сети: " NAME
read -p "Введите название директории ноды: " DIR
read -p "Введите Имя бинарника: " BIN

#NAME=juno
#DIR=juno
#BIN=junod

sudo -v
echo -e "\n\e[33m Этот скрипт производит очистку ноды и переустанавливает базу данных сети из снапшота!\e[0m"
echo -e "\n\e[32m Ссылку на снапшот можно взять на сайте \e[34m https://polkachu.com/tendermint_snapshots/stargaze\e[0m"
echo -e "\e[32m Правый клик на файле для загрузки и там выбрать\e[33m \"Скопировать адрес\"\e[0m"
read -p "Вставьте сюда ссылку на снапшот: " SNAP_LINK
echo -e "\n\e[33m Для продолжения нажмите любую клавишу \e[0m"
read -p ""

wget -O ${NAME}_latest.tar.lz4 $SNAP_LINK --inet4-only
sudo systemctl stop ${NAME}.service
cp $HOME/.$DIR/data/priv_validator_state.json $HOME/.$DIR/priv_validator_state.json.backup
$BIN tendermint unsafe-reset-all --home $HOME/.$DIR --keep-addr-book
rm -r ~/.$DIR/wasm
lz4 -c -d ${NAME}_latest.tar.lz4  | tar -x -C $HOME/.$DIR
mv $HOME/.$DIR/priv_validator_state.json.backup $HOME/.$DIR/data/priv_validator_state.json
sudo systemctl start ${NAME}.service
sudo journalctl -u $NAME -f --output cat
rm -v ${NAME}_latest.tar.lz4
