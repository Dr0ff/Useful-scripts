#!/bin/bash

while true; do
    # Ask for process name
    echo "Enter the process name to monitor (or a part of it, e.g., starsd):"
    read PROCESS_PART

    # Find all matching processes
    MATCHING_PROCESSES=$(pgrep -al "^$PROCESS_PART" | awk '{print $2}')

    if [[ -z "$MATCHING_PROCESSES" ]]; then
        echo "No processes found matching '$PROCESS_PART'. Please try again."
        continue
    fi

    echo "Matching processes:"
    # Print the list of matching processes, with numbers
    PROCESS_LIST=()
    i=1
    while IFS= read -r line; do
        echo "$i. $line"
        PROCESS_LIST+=("$line")
        ((i++))
    done <<< "$MATCHING_PROCESSES"
    
    echo "Enter the number corresponding to the process you want to monitor:"
    read SELECTED_NUMBER

    # Validate the number input
    if ! [[ "$SELECTED_NUMBER" =~ ^[0-9]+$ ]] || [ "$SELECTED_NUMBER" -lt 1 ] || [ "$SELECTED_NUMBER" -gt "${#PROCESS_LIST[@]}" ]; then
        echo "Invalid selection. Please try again."
        continue
    fi

    # Get the selected process name
    SELECTED_PROCESS="${PROCESS_LIST[$SELECTED_NUMBER - 1]}"

    echo "You selected process '$SELECTED_PROCESS'. Proceeding with the next steps."
    break
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

# Process name to monitor
PROCESS_NAME="$SELECTED_PROCESS"

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

# Check if the limit is exceeded
if [[ "\$MEMORY_USAGE" -gt "\$MEMORY_LIMIT_MB" ]]; then
    echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for \$PROCESS_NAME. Restarting service...\n" >> /var/log/memory_check.log

    # Get the service name and restart it
    SERVICE_NAME=\$(cat /proc/\$(pidof "\$PROCESS_NAME")/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')

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
