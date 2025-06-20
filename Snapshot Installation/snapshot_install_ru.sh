#!/bin/bash

# Удаление предыдущего скрипта
rm -rf snapshot_install.sh

# Очистка экрана и загрузка лого
clear

show_logo() {
    echo -e "\e[92m"
    curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.txt
    echo -e "\e[0m"
}

show_logo


echo -e "\e[37m -----------------------------------------------------------\e[0m"
echo -e "\e[93m            Этот скрипт производит очистку ноды\n      и переустанавливает базу данных сети из снапшота!\e[0m"
echo -e "\e[37m -----------------------------------------------------------\n\e[0m"

echo -e "\n\e[93m                      --- Настройки ---\e[0m"

echo -e "\n\e[7;97mКак называется ваша сеть? (пример: sentinel, stargaze, etc...)\n\e[0m"
read -p "Введите имя сети: " NAME
echo -e "\n\e[7;97mВ какой директории находится нода? (.sentinelhub, .starsd, etc...)\n\e[0m"
read -p "Введите название: " DIR

# Adding dot if needed
DIR="$(echo -e "${DIR}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ ! -z "$DIR" && ! "$DIR" =~ ^\. ]]; then
    DIR=".$DIR"
fi

echo -e "\n\e[7;97mКак называется DAEMON (бинарник)  (пример: junod, starsd, sentinelhub...)\n\e[0m"
read -p "Введите имя бинарника: " BIN

echo -e "\n\e[93m            Настройки которые будут использоваться:\e[0m"

echo -e "\n\e[93m Имя сети:         \e[1;97m${NAME}\e[0m"
echo -e "\e[93m Директория ноды:\e[1;97m ${DIR}\e[0m"
echo -e "\e[93m Название DAEMON:\e[1;97m  ${BIN}\e[0m"

echo -e "\n\e[92m Для продолжения нажмите любую клавишу\e[0m"
echo -e "\e[91m Или CTRL+C, для прерывания процесса\e[0m"
read -p " "

#NAME=juno
#DIR=juno
#BIN=junod


clear
show_logo


echo -e "\n\e[93m                           --- Получение снапшота ---\e[0m"


echo -e "\n\e[7;97mТеперь нам необходима ссылка на снапшот\e[0m"
echo -e "\n\e[93m        Перейдите на сайт: \e[97m https://polkachu.com/tendermint_snapshots/${NAME}\e[0m"
echo -e "\e[93m    ⚠️  Найдите снапшот!\e[0m"
echo -e "\e[93m        Правый клик на ссылке для загрузки файла и там выбрать\e[37m \"Копировать адрес ссылки\"\n\e[0m"
read -p "Вставьте ссылку на снапшот: " SNAP_LINK
echo -e "\n\e[92m Для продолжения нажмите любую клавишу \e[0m"
read -p ""

echo -e "\n\e[93m                           --- Скачиваю снапшот ---\n\e[0m"

wget -O ${NAME}_latest.tar.lz4 $SNAP_LINK --inet4-only

if [ $? -ne 0 ]; then
    echo -e "\n\e[91m ОШИБКА: Не удалось скачать снапшот!\e[0m"
    echo -e "\e[93m Пожалуйста, проверьте правильность ссылки и ваше интернет-соединение.\e[0m"
    echo -e "\e[93m Прерываю выполнение скрипта.\e[0m"
    exit 1
fi

clear
show_logo

echo -e "\n\e[93m                               --- Установка ---\e[0m"
echo -e "\n\e[93m Возможно потребуется пароль SUDO \n\e[0m"

sudo -v

sudo systemctl stop ${NAME}.service
cp $HOME/.$DIR/data/priv_validator_state.json $HOME/.$DIR/priv_validator_state.json.backup
$BIN tendermint unsafe-reset-all --home $HOME/.$DIR --keep-addr-book
rm -rf ~/$DIR/wasm
lz4 -c -d ${NAME}_latest.tar.lz4  | tar -x -C $HOME/.$DIR
mv $HOME/.$DIR/priv_validator_state.json.backup $HOME/.$DIR/data/priv_validator_state.json
sudo systemctl start ${NAME}.service
rm -v ${NAME}_latest.tar.lz4
sudo journalctl -u $NAME -f --output cat
