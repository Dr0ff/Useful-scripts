#!/bin/bash
clear


logo=$(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

show_logo() {
    bash -c "$logo"
}

show_logo

# --- 1. Выбор языка ---
while true; do
  echo -e "\n\e[7;97mPlease choose your language   |   Пожалуйста, выберите язык:\e[0m"
  echo " "
  echo -e "         1. 🇬🇧 English               2. 🇷🇺 Русский\n"
  read -p "> " lang_num_choice

  case "$lang_num_choice" in
    1) LANG="en"; break ;;
    2) LANG="ru"; break ;;
    *)
      echo -e "\n\e[91m     Please enter 1 or 2    |    Введите 1 или 2. \e[0m"
    # echo "Неверный ввод. Введите 1 или 2.\e[0m"
      sleep 2
      ;;
  esac
done
wget -O snapshot_install_${LANG}.sh https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/Snapshot%20Installation/snapshot_install_${LANG}.sh
echo "Downloaded snapshot_install_${LANG}.sh "
bash snapshot_install_${LANG}.sh
