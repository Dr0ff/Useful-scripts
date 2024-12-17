#!/bin/bash

echo " "
echo "We are about to setup few things here:"
echo " "
echo "1. Optimisation mode for your service"
echo "2. Automatically changing ports if you are about to run it as second service"
echo " "

#!/bin/bash

# Prompt the user to enter the configuration directory
read -p "Enter the CONFIG_DIR (e.g., .juno or .xpla): " CONFIG_DIR

# Check if the CONFIG_DIR variable is provided
if [ -z "$CONFIG_DIR" ]; then
    echo "CONFIG_DIR is required. Exiting."
    exit 1
fi

# Convert CONFIG_DIR to service name by removing the leading dot
SERVICE_NAME=$(echo "$CONFIG_DIR" | sed 's/^\.//')

# Base URL for installation documentation
DOC_BASE_URL="https://polkachu.com/installation"

# Verify if the specified directory exists
if [ ! -d "$HOME/$CONFIG_DIR/config" ]; then
    echo "Directory $HOME/$CONFIG_DIR/config does not exist."
    echo "The service may not be installed correctly."
    echo "Please refer to the documentation: $DOC_BASE_URL/$SERVICE_NAME"
    exit 1
fi

# Define required configuration files
CONFIG_FILE="$HOME/$CONFIG_DIR/config/config.toml"
APP_FILE="$HOME/$CONFIG_DIR/config/app.toml"
CLIENT_FILE="$HOME/$CONFIG_DIR/config/client.toml"

# Function to check if all required files exist
check_required_files() {
    local files=("$@")
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Error: Required file $file does not exist."
            echo "The service may not be installed correctly."
            echo "Please refer to the documentation: $DOC_BASE_URL/$SERVICE_NAME"
            exit 1
        fi
    done
}

# Check if all required files exist before proceeding
check_required_files "$CONFIG_FILE" "$APP_FILE" "$CLIENT_FILE"

# Ask the user whether to enable pruning
read -p "Enable pruning? (yes/no): " ENABLE_PRUNING

if [[ "$ENABLE_PRUNING" == "yes" ]]; then
    echo "Enabling pruning and setting indexer to 'null'..."
    # Update pruning settings in app.toml
    sed -i.bak -e 's%"default"%"custom"%g; s%pruning-keep-recent = "0"%pruning-keep-recent = "100"%g; s%pruning-interval = "0"%pruning-interval = "10"%g; /pruning-keep-recent = "100"/a\pruning-keep-every = "0"' "$APP_FILE"
    echo "Pruning settings updated in $APP_FILE."

    # Update indexer setting in config.toml
    sed -i.bak -e "s%indexer = \"kv\"%indexer = \"null\"%g" "$CONFIG_FILE"
    echo "Indexer settings updated in $CONFIG_FILE."
else
    echo "Pruning and indexer configuration will not be changed."
fi

# Ask the user whether to change ports for the second service
read -p "Is this the second service? Change ports? (yes/no): " CHANGE_PORTS

if [[ "$CHANGE_PORTS" == "yes" ]]; then
    echo "Changing ports for the second service..."
    # Update ports in config.toml
    sed -i.bak -e "s%:26658%:27658%; s%:26657%:27657%; s%:6060%:6160%; s%:26656%:27656%; s%:26660%:27660%" "$CONFIG_FILE"
    echo "Ports updated in $CONFIG_FILE."

    # Update ports in app.toml
    sed -i.bak -e "s%:9090%:9190%; s%:9091%:9191%; s%:1317%:1417%; s%:8545%:8645%; s%:8546%:8646%; s%:6065%:6165%" "$APP_FILE"
    echo "Ports updated in $APP_FILE."

    # Update ports in client.toml
    sed -i.bak -e "s%:26657%:27657%" "$CLIENT_FILE"
    echo "Ports updated in $CLIENT_FILE."
else
    echo "Ports will not be changed."
fi

echo "Configuration files updated successfully for $CONFIG_DIR."
