#!/bin/bash

# Запрос директории у пользователя
read -p "Enter the CONFIG_DIR (e.g., .juno or .xpla): " CONFIG_DIR

# Проверка, указана ли директория
if [ -z "$CONFIG_DIR" ]; then
    echo "CONFIG_DIR is required. Exiting."
    exit 1
fi

# Проверяем, существует ли указанная директория
if [ ! -d "$HOME/$CONFIG_DIR/config" ]; then
    echo "Directory $HOME/$CONFIG_DIR/config does not exist. Exiting."
    exit 1
fi

# Спрашиваем у пользователя, нужно ли включать pruning
read -p "Enable pruning? (yes/no): " ENABLE_PRUNING

if [[ "$ENABLE_PRUNING" == "yes" ]]; then
    echo "Enabling pruning and setting indexer to 'null'..."
    # Настройка pruning в app.toml
    sed -i.bak -e 's%"default"%"custom"%g; s%pruning-keep-recent = "0"%pruning-keep-recent = "100"%g; s%pruning-interval = "0"%pruning-interval = "10"%g; /pruning-keep-recent = "100"/a\pruning-keep-every = "0"' "$HOME/$CONFIG_DIR/config/app.toml"
    # Настройка indexer в config.toml
    sed -i.bak -e "s%indexer = \"kv\"%indexer = \"null\"%g" "$HOME/$CONFIG_DIR/config/config.toml"
    echo "Pruning and indexer configuration has been updated."
else
    echo "Pruning and indexer configuration will not be changed."
fi

# Спрашиваем у пользователя, нужно ли менять порты
read -p "Is this the second service? Change ports? (yes/no): " CHANGE_PORTS

if [[ "$CHANGE_PORTS" == "yes" ]]; then
    echo "Changing ports for the second service..."
    # Замена портов в config.toml
    sed -i.bak -e "s%:26658%:27658%; s%:26657%:27657%; s%:6060%:6160%; s%:26656%:27656%; s%:26660%:27660%" "$HOME/$CONFIG_DIR/config/config.toml"
    # Замена портов в app.toml
    sed -i.bak -e "s%:9090%:9190%; s%:9091%:9191%; s%:1317%:1417%; s%:8545%:8645%; s%:8546%:8646%; s%:6065%:6165%" "$HOME/$CONFIG_DIR/config/app.toml"
    # Замена портов в client.toml
    sed -i.bak -e "s%:26657%:27657%" "$HOME/$CONFIG_DIR/config/client.toml"
    echo "Ports have been changed."
else
    echo "Ports will not be changed."
fi

echo "Configuration files updated successfully for $CONFIG_DIR."
