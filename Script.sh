#!/bin/bash

while true; do
    # Ask for process name, memory limit, and directory to save the script
    echo "Enter the process name to monitor (e.g., starsd):"
    read PROCESS_NAME

    # Check if the process is running
    PROCESS_COUNT=$(pgrep -c "$PROCESS_NAME")

    if [[ "$PROCESS_COUNT" -eq 0 ]]; then
        echo "Error: The process '$PROCESS_NAME' is not running."
        echo "What would you like to do?"
        echo "1. Check the process name and enter it again"
        echo "2. Continue with the entered process name"
        read -p "Choose an option (1 or 2): " CHOICE

        case $CHOICE in
            1)
                # Repeat the process name input
                continue
                ;;
            2)
                # Proceed with the entered name (even though the process is not running)
                echo "Proceeding with the entered process name '$PROCESS_NAME'."
                break
                ;;
            *)
                # Invalid choice
                echo "Invalid choice. Please try again."
                continue
                ;;
        esac
    else
        echo "The process '$PROCESS_NAME' is running. Proceeding with the next steps."
        break
    fi
done

# Ask for memory limit and directory to save the script
echo "Enter the memory limit in kilobytes (e.g., 300000 KB for 300 MB):"
read MEMORY_LIMIT_MB

echo "Enter the directory to save the script (e.g., .juno, .starsd...):"
echo "Directory where your node is installed"
read SCRIPT_DIR

# Check if the specified directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Error: The directory '$SCRIPT_DIR' does not exist."
    echo "What would you like to do?"
    echo "1. Enter the directory again"
    echo "2. Exit"
    read -p "Choose an option (1 or 2): " CHOICE

    case $CHOICE in
        1)
            # Repeat the directory input
            continue
            ;;
        2)
            # Exit the script
            echo "Exiting the script."
            exit 0
            ;;
        *)
            # Invalid choice
            echo "Invalid choice. Please try again."
            continue
            ;;
    esac
else
    # Form the path to save the script
    SCRIPT_PATH="$SCRIPT_DIR/memory_check.sh"

    # Create the main script
    cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash

# Process name to monitor
PROCESS_NAME="$PROCESS_NAME"

# Get the service name to restart
SERVICE_NAME=\$(cat /proc/\$(pidof "\$PROCESS_NAME")/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')

# Memory limit in kilobytes
MEMORY_LIMIT_MB=$MEMORY_LIMIT_MB

# Check if the process is running
PROCESS_COUNT=\$(pgrep -c "\$PROCESS_NAME")

if [[ "\$PROCESS_COUNT" -eq 0 ]]; then
    echo -e "\$(date): Process \$PROCESS_NAME is not running. Skipping memory check.\n" >> /var/log/memory_check.log
    exit 0
fi

# Get the memory usage of the process (in KB)
MEMORY_USAGE=\$(ps --no-headers -o rss -p \$(pgrep "\$PROCESS_NAME") | awk '{sum+=$1} END {print sum}')
#MEMORY_USAGE=$(ps --no-headers -o rss -p $(pgrep "$PROCESS_NAME") | awk '{sum+=$1} END {print sum}')

# Check if the limit is exceeded
if [[ "\$MEMORY_USAGE" -gt "\$MEMORY_LIMIT_MB" ]]; then
    echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for \$PROCESS_NAME. Restarting service...\n" >> /var/log/memory_check.log

    # Restart the service
    if systemctl restart "\$SERVICE_NAME"; then
        echo -e "\$(date): Service \$SERVICE_NAME restarted successfully.\n" >> /var/log/memory_check.log
    else
        echo -e "\$(date): Failed to restart \$SERVICE_NAME.\n" >> /var/log/memory_check.log
    fi
#else
#    echo -e "\$(date): Memory usage is normal: \$MEMORY_USAGE KB\n" >> /var/log/memory_check.log
fi
EOF

    # Make the new script executable
#    chmod +x "$SCRIPT_PATH"

    # Information about the created script
    echo "Script created and saved in $SCRIPT_PATH"
fi
