#!/bin/bash

while true; do
    # Ask for process name
    echo "Enter the process name to monitor (or a part of it, e.g., starsd):"
    read PROCESS_PART

    # Find all matching processes
    MATCHING_PROCESSES=$(pgrep -al "^$PROCESS_PART")

    if [[ -z "$MATCHING_PROCESSES" ]]; then
        echo "No processes found matching '$PROCESS_PART'. Please try again."
        continue
    fi

    echo "Matching processes:"
    echo "$MATCHING_PROCESSES"
    echo "Enter the PID of the process you want to monitor or type 'restart' to search again:"
    read SELECTED_PID

    if [[ "$SELECTED_PID" == "restart" ]]; then
        continue
    fi

    # Verify that the selected PID corresponds to a process
    PROCESS_NAME=$(ps -p "$SELECTED_PID" -o comm= 2>/dev/null)

    if [[ -z "$PROCESS_NAME" ]]; then
        echo "Invalid PID. Please try again."
        continue
    else
        echo "You selected process '$PROCESS_NAME' with PID $SELECTED_PID. Proceeding with the next steps."
        break
    fi
done

# Ask for memory limit
echo "Enter the memory limit in kilobytes (e.g., 300000 KB for 300 MB):"
read MEMORY_LIMIT_MB

# Directory input and validation
while true; do
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
        # If the directory exists, break the loop
        break
    fi
done

# Form the path to save the script
SCRIPT_PATH="$SCRIPT_DIR/memory_check.sh"

# Create the main script
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash

# PID to monitor
MONITORED_PID="$SELECTED_PID"

# Memory limit in kilobytes
MEMORY_LIMIT_MB=$MEMORY_LIMIT_MB

# Check if the process is running
if ! ps -p "\$MONITORED_PID" > /dev/null 2>&1; then
    echo -e "\$(date): Process with PID \$MONITORED_PID is not running. Skipping memory check.\n" >> /var/log/memory_check.log
    exit 0
fi

# Get the memory usage of the process (in KB)
MEMORY_USAGE=\$(ps --no-headers -o rss -p "\$MONITORED_PID" | awk '{sum+=$1} END {print sum}')

# Check if the limit is exceeded
if [[ "\$MEMORY_USAGE" -gt "\$MEMORY_LIMIT_MB" ]]; then
    echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for process with PID \$MONITORED_PID. Restarting service...\n" >> /var/log/memory_check.log

    # Get the service name and restart it
    SERVICE_NAME=\$(cat /proc/\$MONITORED_PID/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')

    if systemctl restart "\$SERVICE_NAME"; then
        echo -e "\$(date): Service \$SERVICE_NAME restarted successfully.\n" >> /var/log/memory_check.log
    else
        echo -e "\$(date): Failed to restart \$SERVICE_NAME.\n" >> /var/log/memory_check.log
    fi
fi
EOF

# Make the new script executable
chmod +x "$SCRIPT_PATH"

# Information about the created script
echo "Script created and saved in $SCRIPT_PATH"
