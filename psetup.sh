#!/bin/bash

clear

show_logo() {
    echo -e "\e[92m"
    curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.txt
    echo -e "\e[0m"
}

show_logo

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

# Function to prompt user for yes/no input with support for y/n
prompt_yes_no() {
    local prompt_message="$1"
    while true; do
        read -p "$prompt_message (yes/no): " answer
        case "${answer,,}" in  # Convert input to lowercase
            y|yes) return 0 ;;  # Return success for "yes" or "y"
            n|no) return 1 ;;   # Return failure for "no" or "n"
            *) echo "Please enter yes, no, y, or n." ;;
        esac
    done
}

# Function to calculate new ports based on service number and step
calculate_ports() {
    local base_port="$1"
    local step="$2"
    local service_number="$3"
    echo $((base_port + step * (service_number - 1)))
}

# Check if all required files exist before proceeding
check_required_files "$CONFIG_FILE" "$APP_FILE" "$CLIENT_FILE"

# Ask the user whether to enable pruning
if prompt_yes_no "Enable pruning?"; then
    echo "Enabling pruning and setting indexer to 'null'..."
    # Update pruning settings in app.toml


	# Replace the values for pruning-keep-recent, pruning-interval
	sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" "$APP_FILE"
	sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" "$APP_FILE"

#	# Check if 'pruning-keep-every' exists (with optional leading spaces), and if not, add it after 'pruning-interval'
#	if ! grep -q '^\s*pruning-keep-every' "$APP_FILE"; then
#	    sed -i -e '/^pruning-keep-recent = "100"/a\pruning-keep-every = \"0\"' "$APP_FILE"
#	else
#	    echo "'pruning-keep-every' is already set, skipping addition."
#	fi
    echo "Pruning settings updated in $APP_FILE."

    # Update indexer setting in config.toml
    sed -i.bak -e "s%indexer = \"kv\"%indexer = \"null\"%g" "$CONFIG_FILE"
    echo "Indexer settings updated in $CONFIG_FILE."
else
    echo "Pruning and indexer configuration will not be changed."
fi

# Ask the user for the service number to determine port adjustments
if prompt_yes_no "Do you want to configure ports for a specific service (e.g., second, third, etc.)?"; then
    read -p "Enter the service number (2 for second, 3 for third, etc.): " SERVICE_NUMBER
    if ! [[ "$SERVICE_NUMBER" =~ ^[2-9][0-9]*$ ]]; then
        echo "Invalid service number. Must be an integer greater than 1. Exiting."
        exit 1
    fi

    PORT_STEP=1000  # Define the step for port adjustments
    echo "Adjusting ports for service number $SERVICE_NUMBER with step $PORT_STEP..."

    # Calculate new ports for each configuration
    NEW_RPC_PORT=$(calculate_ports 26657 "$PORT_STEP" "$SERVICE_NUMBER")
    NEW_P2P_PORT=$(calculate_ports 26656 "$PORT_STEP" "$SERVICE_NUMBER")
    NEW_API_PORT=$(calculate_ports 1317 "$PORT_STEP" "$SERVICE_NUMBER")
    NEW_GRPC_PORT=$(calculate_ports 9090 "$PORT_STEP" "$SERVICE_NUMBER")
    NEW_GRPC_WEB_PORT=$(calculate_ports 9091 "$PORT_STEP" "$SERVICE_NUMBER")

    # Update ports in config.toml
    sed -i.bak -e "s%:26658%:$(calculate_ports 26658 "$PORT_STEP" "$SERVICE_NUMBER")%; \
                   s%:26657%:$NEW_RPC_PORT%; \
                   s%:6060%:$(calculate_ports 6060 "$PORT_STEP" "$SERVICE_NUMBER")%; \
                   s%:26656%:$NEW_P2P_PORT%; \
                   s%:26660%:$(calculate_ports 26660 "$PORT_STEP" "$SERVICE_NUMBER")%" "$CONFIG_FILE"
    echo "Ports updated in $CONFIG_FILE."

    # Update ports in app.toml
    sed -i.bak -e "s%:9090%:$NEW_GRPC_PORT%; \
                   s%:9091%:$NEW_GRPC_WEB_PORT%; \
                   s%:1317%:$NEW_API_PORT%; \
                   s%:8545%:$(calculate_ports 8545 "$PORT_STEP" "$SERVICE_NUMBER")%; \
                   s%:8546%:$(calculate_ports 8546 "$PORT_STEP" "$SERVICE_NUMBER")%; \
                   s%:6065%:$(calculate_ports 6065 "$PORT_STEP" "$SERVICE_NUMBER")%" "$APP_FILE"
    echo "Ports updated in $APP_FILE."

    # Update ports in client.toml
    sed -i.bak -e "s%:26657%:$NEW_RPC_PORT%" "$CLIENT_FILE"
    echo "Ports updated in $CLIENT_FILE."
else
    echo "Ports will not be changed."
fi

echo "Configuration files updated successfully for $CONFIG_DIR."
