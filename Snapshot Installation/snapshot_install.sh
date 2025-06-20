#!/bin/bash
clear


logo=$(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)

show_logo() {
    bash -c "$logo"
}

show_logo

# --- 1. Выбор языка ---
while true; do
  echo -e "${COLOR_INFO}Please choose your language / Пожалуйста, выберите язык:${RESET}"
  echo -e " 1. 🇬🇧 English"
  echo -e " 2. 🇷🇺 Русский"
  read -p " " lang_num_choice

  case "$lang_num_choice" in
    1) LANG="en"; break ;;
    2) LANG="ru"; break ;;
    *)
      echo -e "\n${COLOR_WARNING}Invalid input. Please enter 1 or 2."
      echo "Неверный ввод. Введите 1 или 2.${RESET}"
      sleep 2
      ;;
  esac
done
wget -O snapshot_install_${LANG}.sh https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/in_progress/snapshot_install_${LANG}.sh
echo "Downloaded snapshot_install_${LANG}.sh "
bash snapshot_install_${LANG}.sh
