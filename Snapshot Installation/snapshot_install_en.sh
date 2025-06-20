#!/bin/bash

# Removing the previous script 
rm -rf snapshot_install.sh

# Clear the screen and get logo
clear

show_logo() {
    echo -e "\e[92m"
    curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.txt
    echo -e "\e[0m"
}

show_logo


echo -e "\n\e[37m  ------------------------------------------------------\e[0m"
echo -e "\e[93m       This script cleans the node and reinstalls\n      the network database from a snapshot!\e[0m"
echo -e "\e[37m  ------------------------------------------------------\n\e[0m"

echo -e "\n\e[1;93m                 --- Settings ---\e[0m"

echo -e "\n\e[7;97mWhat is your network's name? (e.g., sentinel, stargaze, etc...)\n\e[0m"
read -p "Enter the network name: " NAME
echo -e "\n\e[7;97mIn which directory is the node located? (.sentinelhub, .starsd, etc...)\n\e[0m"
read -p "Enter the name: " DIR

# Adding dot if needed
DIR="$(echo -e "${DIR}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ ! -z "$DIR" && ! "$DIR" =~ ^\. ]]; then
    DIR=".$DIR"
fi

echo -e "\n\e[7;97mWhat is the DAEMON (binary) name? (e.g., junod, starsd, sentinelhub...)\n\e[0m"
read -p "Enter the binary name: " BIN

echo -e "\n\e[93m                Settings to be used:\e[0m"

echo -e "\n\e[93m Network Name:\e[1;97m ${NAME}\e[0m"
echo -e "\e[93m Node Directory:\e[1;97m ${DIR}\e[0m"
echo -e "\e[93m DAEMON Name:\e[97m ${BIN}\e[0m"

echo -e "\n\e[92m Press any key to continue\e[0m"
echo -e "\e[91m Or CTRL+C to interrupt the process\e[0m"
read -p " "

#NAME=juno
#DIR=juno
#BIN=junod

clear
show_logo

echo -e "\n\e[93m             --- Getting the snapshot ---\e[0m"
echo -e "\n\e[7;97m You need to provide a link to download snapshot\e[0m"
echo -e "\n\e[93m          Go to the website: \e[97m https://polkachu.com/tendermint_snapshots /${NAME}\e[0m"
echo -e "\e[93m     ⚠️   Find the snapshot!\e[0m"
echo -e "\e[93m          Right-click on the download link for the file and select\e[37m \"Copy Link Address\"\n\e[0m"
read -p "Paste the snapshot link: " SNAP_LINK
echo -e "\n\e[92m Press any key to continue \e[0m"
read -p ""

echo -e "\n\e[93m             --- Downloading the snapshot ---\n\e[0m"

wget -O ${NAME}_latest.tar.lz4 $SNAP_LINK --inet4-only

if [ $? -ne 0 ]; then
    echo -e "\n\e[91m ERROR: Failed to download the snapshot!\e[0m"
    echo -e "\e[93m Please check the link's correctness and your internet connection.\e[0m"
    echo -e "\e[93m Aborting script execution.\e[0m"
    exit 1
fi

clear
show_logo

echo -e "\n\e[93m                 --- Installation ---\e[0m"
echo -e "\n\e[93m SUDO password may be required \n\e[0m"

sudo -v

sudo systemctl stop ${NAME}.service
cp $HOME/$DIR/data/priv_validator_state.json $HOME/$DIR/priv_validator_state.json.backup
$BIN tendermint unsafe-reset-all --home $HOME/$DIR --keep-addr-book
rm -rf ~/$DIR/wasm
lz4 -c -d ${NAME}_latest.tar.lz4  | tar -x -C $HOME/$DIR
mv $HOME/$DIR/priv_validator_state.json.backup $HOME/$DIR/data/priv_validator_state.json
sudo systemctl start ${NAME}.service
rm -v ${NAME}_latest.tar.lz4
sudo journalctl -u $NAME -f --output cat
