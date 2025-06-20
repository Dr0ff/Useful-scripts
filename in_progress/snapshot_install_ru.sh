#!/bin/bash
clear

#bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)
logo=$(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

show_logo() {
	bash -c "$logo"
}

show_logo

# --- 1. Выбор языка с флагами ---
while true; do

  echo "Please choose your language / Пожалуйста, выберите язык:"
  echo " 1. 🇬🇧 English"
  echo " 2. 🇷🇺 Русский"
  read -p "> " lang_num_choice

  case "$lang_num_choice" in
    1)
      LANG="en"
      break
      ;;
    2)
      LANG="ru"
      break
      ;;
    *)
      echo
      echo "Invalid input. Please enter 1 or 2."
      echo "Неверный ввод. Введите 1 или 2."

      sleep 2 # Пауза, чтобы пользователь успел прочитать
      ;;
  esac
done
# --- 2. Хранилище текстовых строк (наш словарик) ---
# Мы используем ассоциативные массивы (declare -A)

# Сообщение приветствия
declare -A msg_welcome
msg_welcome[ru]="Этот скрипт производит очистку ноды и переустанавливает базу данных сети из снапшота!"
msg_welcome[en]="🎉 Welcome to my interactive script!"

# Вопрос о имени
declare -A msg_ask_name
msg_ask_name[ru]="Пожалуйста, введите ваше имя:"
msg_ask_name[en]="Please, enter your name:"

# Приветствие пользователя по имени. %s - это место для подстановки переменной.
declare -A msg_hello_user
msg_hello_user[ru]="Привет, %s! Приятно познакомиться."
msg_hello_user[en]="Hello, %s! Nice to meet you."

# Сообщение о завершении
declare -A msg_done
msg_done[ru]="Работа скрипта завершена. Хорошего дня!"
msg_done[en]="Script finished. Have a great day!"


# --- 3. Функция-помощник для вывода текста ---
# Эта функция будет выводить текст на выбранном языке.
# Она использует printf для безопасной подстановки переменных (например, имени).
i18n_printf() {
  local message_map_name=$1[$LANG] # Формируем имя переменной, например "msg_welcome[ru]"
  local format_string="${!message_map_name}" # Получаем саму строку (формат для printf)
  shift # Сдвигаем аргументы, чтобы убрать имя карты

  # Выводим отформатированную строку с остальными аргументами
  printf "$format_string" "$@"
  echo # Добавляем перенос строки для красоты
}


# --- 4. Основная логика скрипта ---
# Обратите внимание, насколько чистым стал код. Никаких if/else для языка.

clear # Очистим экран для красоты
show_logo
# Выводим приветствие
i18n_printf "msg_welcome"
echo # Пустая строка для отступа

# Задаем вопрос и читаем ответ
i18n_printf "msg_ask_name"
read -p "> " USER_NAME

# Приветствуем пользователя по имени, передавая его как аргумент
i18n_printf "msg_hello_user" "$USER_NAME"
echo

# Выводим финальное сообщение
i18n_printf "msg_done"


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
    echo -e "\n\e[91m ОШИБКА: Не удалось скачать снапшот!\e[0m"
    echo -e "\e[93m Пожалуйста, проверьте правильность ссылки и ваше интернет-соединение.\e[0m"
    echo -e "\e[93m Прерываю выполнение скрипта.\e[0m"
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
