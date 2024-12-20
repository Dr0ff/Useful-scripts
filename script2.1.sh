#!/bin/bash
<<<<<<< HEAD
# Version: 1.0.2
=======
# Version: 1.0.12
>>>>>>> a413cdd (changes)

# Prompt the user to choose between manual input and search for the process
echo "We need the process name to monitor."
echo "0. Manually input the process name."
echo "1. Help with finding the process name."
read -p "Choose 0 or 1: " USER_CHOICE

<<<<<<< HEAD
    # Find all matching processes using ps and grep, then remove the PID and other arguments
    MATCHING_PROCESSES=$(ps -eo pid,comm | grep "$PROCESS_PART" | awk '{print $2}' | sort | uniq)
=======
if ! [[ "$USER_CHOICE" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid input. Please enter a number."
  exit 1
fi
>>>>>>> a413cdd (changes)

# Check if the user chose manual input
if [ "$USER_CHOICE" -eq 0 ]; then
  # Manual input mode
  echo "Manual input mode. You can enter the full process name below."
  echo "Enter the process name manually:"
  read SELECTED_PROCESS
  
  # Check if the input process name is empty or contains special characters
  if [ -z "$SELECTED_PROCESS" ] || ! [[ "$SELECTED_PROCESS" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Input process name contains special characters or is empty."
    exit 1
  fi
  
  # Break out of the loop
  break
elif [ "$USER_CHOICE" -eq 1 ]; then
  # Automatic search mode
  echo "Enter the process name or part of it:"
  read PROCESS_PART
  
  # Check if the input process part is empty or contains special characters
  if [ -z "$PROCESS_PART" ] || ! [[ "$PROCESS_PART" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Input process part contains special characters or is empty."
    exit 1
  fi
  
  # Find matching processes
  MATCHING_PROCESSES=$(ps -eo pid,comm | grep "$PROCESS_PART" | awk '{print $2}' | sort | uniq)
  
  # Check if no matching processes were found
  if [ -z "$MATCHING_PROCESSES" ]; then
    echo "No processes found matching '$PROCESS_PART'. Please try again."
    continue
  fi
  
  # Display the list of matching processes with numbers
  PROCESS_LIST=()
  i=1
  while IFS= read -r line; do
    echo "$i. $line"
    PROCESS_LIST+=("$line")
    ((i++))
  done <<< "$MATCHING_PROCESSES"
  
  # Prompt the user to select a process
  echo "Enter the number corresponding to the process you want to monitor (or enter 0 to manually input the process name):"
  read SELECTED_NUMBER_OR_MANUAL
  
  # Check if the user chose manual input
  if [ "$SELECTED_NUMBER_OR_MANUAL" -eq 0 ]; then
    # Manual input mode
    echo "Enter the process name manually:"
    read SELECTED_PROCESS
    
    # Check if the input process name is empty or contains special characters
    if [ -z "$SELECTED_PROCESS" ] || ! [[ "$SELECTED_PROCESS" =~ ^[a-zA-Z0-9]+$ ]]; then
      echo "Error: Input process name contains special characters or is empty."
      exit 1
    fi
<<<<<<< HEAD

    echo "Matching processes:"
    # Print the list of matching processes with numbers
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
=======
  else
    # Validate the selected number
    if ! [[ "$SELECTED_NUMBER_OR_MANUAL" =~ ^[0-9]+$ ]] || [ "$SELECTED_NUMBER_OR_MANUAL" -lt 1 ] || [ "$SELECTED_NUMBER_OR_MANUAL" -gt "${#PROCESS_LIST[@]}" ]; then
      echo "Error: Invalid selection. Please try again."
      continue
>>>>>>> a413cdd (changes)
    fi
    
    # Get the selected process name
    SELECTED_PROCESS="${PROCESS_LIST[$SELECTED_NUMBER_OR_MANUAL - 1]}"
  fi
else
  echo "Error: Invalid choice. Please enter 0 for manual input or 1 for process search."
  continue
fi

<<<<<<< HEAD
    # Get the selected process name
    SELECTED_PROCESS="${PROCESS_LIST[$SELECTED_NUMBER - 1]}"

    echo "You selected process '$SELECTED_PROCESS'. Proceeding with the next steps."
    break
done

# Ask for memory limit
=======
# Prompt the user to enter the memory limit
>>>>>>> a413cdd (changes)
echo "Enter the memory limit in kilobytes (e.g., 300000 KB for 300 MB):"
read MEMORY_LIMIT_MB

# Check if the input memory limit is a number
if ! [[ "$MEMORY_LIMIT_MB" =~ ^[0-9]+$ ]]; then
  echo "Error: Input memory limit is not a number."
  exit 1
fi

# Prompt the user to select a directory
echo "Enter the directory to save the script (e.g., .xpla, .xpladir...) or enter 0 to manually input the directory."
echo "This will scan for existing directories starting with '.' and matching the process name."

# List directories that start with a dot and match the process name
DIRECTORIES=$(find . -maxdepth 1 -type d -name ".${PROCESS_PART}*")

# Check if no directories were found
if [ -z "$DIRECTORIES" ]; then
  echo "No directories found starting with a dot and matching the process name. Please try again."
  continue
fi

# Display the list of directories with numbers
DIRECTORY_LIST=()
i=1
while IFS= read -r dir; do
  echo "$i. $dir"
  DIRECTORY_LIST+=("$dir")
  ((i++))
done <<< "$DIRECTORIES"

# Prompt the user to select a directory
echo "Enter the number corresponding to the directory you want to use (or enter 0 to manually input the directory):"
read SELECTED_DIRECTORY_NUMBER_OR_MANUAL

# Check if the user chose manual input for directory
if [ "$SELECTED_DIRECTORY_NUMBER_OR_MANUAL" -eq 0 ]; then
  # Manual input mode for directory
  echo "Enter the directory manually (with dot prefix, e.g., .xpla):"
  read SELECTED_DIRECTORY
else
  # Validate the selected directory number
  if ! [[ "$SELECTED_DIRECTORY_NUMBER_OR_MANUAL" =~ ^[0-9]+$ ]] || [ "$SELECTED_DIRECTORY_NUMBER_OR_MANUAL" -lt 1 ] || [ "$SELECTED_DIRECTORY_NUMBER_OR_MANUAL" -gt "${#DIRECTORY_LIST[@]}" ]; then
    echo "Error: Invalid selection. Please try again."
    continue
  fi
  
  # Get the selected directory
  SELECTED_DIRECTORY="${DIRECTORY_LIST[$SELECTED_DIRECTORY_NUMBER_OR_MANUAL - 1]}"
fi

# Print the selected directory
echo "You selected directory '$SELECTED_DIRECTORY'. Proceeding with the next steps."

# Form the path to save the script
SCRIPT_PATH="$SELECTED_DIRECTORY/memory_check.sh"

# Create the main script (overwrites the existing file)
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
<<<<<<< HEAD
# Version: 1.0.2
=======
# Version: 1.0.12
>>>>>>> a413cdd (changes)

# Process name to monitor
PROCESS_NAME="$SELECTED_PROCESS"

# Memory limit in kilobytes
MEMORY_LIMIT_MB=$MEMORY_LIMIT_MB

# Check if the process is running
PROCESS_COUNT=\$(pgrep -c "\$PROCESS_NAME")

if [[ "\$PROCESS_COUNT" -eq 0 ]]; then
<<<<<<< HEAD
    echo -e "\$(date): Process \$PROCESS_NAME is not running. Skipping memory check.\n" >> /var/log/memory_check.log
    exit 0
=======
  echo -e "\$(date): Process \$PROCESS_NAME is not running. Skipping memory check.\n" >> /var/log/memory_check.log
  exit 0
>>>>>>> a413cdd (changes)
fi

# Get the memory usage of the process (in KB)
MEMORY_USAGE=\$(ps --no-headers -o rss -p \$(pgrep "\$PROCESS_NAME") | awk '{sum+=$1} END {print sum}')

# Check if the limit is exceeded
if [[ "\$MEMORY_USAGE" -gt "\$MEMORY_LIMIT_MB" ]]; then
<<<<<<< HEAD
    echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for \$PROCESS_NAME. Restarting service...\n" >> /var/log/memory_check.log

    # Get the service name and restart it
    SERVICE_NAME=\$(cat /proc/\$(pidof "\$PROCESS_NAME")/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')
=======
  echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for \$PROCESS_NAME. Restarting service...\n" >> /var/log/memory_check.log

  # Get the service name and restart it
  SERVICE_NAME=\$(cat /proc/\$(pidof "\$PROCESS_NAME")/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')
>>>>>>> a413cdd (changes)

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

