#!/bin/bash
# Version: 1.0.12

# Function to display error and exit
error_exit() {
  echo "Error: $1"
  exit 1
}

bash <(curl -s https://raw.githubusercontent.com/Dr0ff/Useful-scripts/refs/heads/main/tt.logo.sh)


echo -e "\e[33m"
echo "/////////////////////////////////////////////////////////////////////////////////////////////"
echo "//                                                                                         //"
echo -e "//       \e[0mThis script will help you to configure and install the memory usage monitor     \e[33m  //"
echo -e "//       \e[0mfor your validator node, just follow few simple steps bellow \e[33m                     //"
echo "//                                                                                         //"
echo "/////////////////////////////////////////////////////////////////////////////////////////////"
echo " "
echo " "
echo " "


echo -e "\e[32m Now we need to find the process to monitor the memory consumption\e[0m"
echo  ""

# Function to prompt for manual or search input
prompt_process_name() {
  while true; do
    echo -e "\e[33mEnter the process name or part of it (e.g xpl ju juno ...)\e[0m"
    read -p "" PROCESS_PART

    if [[ -z "$PROCESS_PART" ]] || ! [[ "$PROCESS_PART" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      echo -e "\e[31mInvalid input. Please try again.\e[0m\n"
    else
      MATCHING_PROCESSES=$(ps -eo comm | grep -i "$PROCESS_PART" | sort | uniq)

      if [[ -z "$MATCHING_PROCESSES" ]]; then
        echo -e "\e[31mNo matching processes found. Please try again.\e[0m\n"
      else
        # Display the matching processes
        echo -e "\n\e[33mMATCHING PROCESSES:\e[0m"
        PROCESS_LIST=()
        i=1

        while IFS= read -r process; do
          echo "$i. $process"
          PROCESS_LIST+=("$process")
          ((i++))
        done <<< "$MATCHING_PROCESSES"

        while true; do
          echo -e "\n\e[33mChoose a process\e[0m"
          read -p "" SELECTION


	if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
	  if [[ "$SELECTION" -ge 1 && "$SELECTION" -le "${#PROCESS_LIST[@]}" ]]; then
	    SELECTED_PROCESS="${PROCESS_LIST[$SELECTION - 1]}"
	    echo -e "\n\e[33mPROCESS NAME SELECTED: \e[32m$SELECTED_PROCESS\e[0m\n"
	    break 2
	  else
	    echo -e "\n\e[31mInvalid selection. Please try again.\e[0m"
	  fi
	else
	  echo -e "\n\e[31mInvalid input. Please enter a number.\e[0m"
	fi
        done
      fi
    fi
  done
}

# Function to prompt for directory
prompt_directory() {
  while true; do
    echo -e "\n\e[32mWe need to find the directory to save this script (e.g. .xpla or .juno...)\e[0m"
    echo "Searching for matching directories..."

    # Выполним команду поиска с фильтрацией точки в имени и исключением текущей директории
    DIRECTORIES=$(find . -maxdepth 1 -type d -name ".${SELECTED_PROCESS:0:4}*" 2>/dev/null | sed 's/^\.\///g')

    if [[ -z "$DIRECTORIES" ]]; then
      echo -e "\n\e[31mNo matching directories found.\n\e[33mLooks like the directory doesn't exist.\e[0m"
      echo -e "\n\e[33mPlease check the installation directory and try again\nExiting...\e[0m"
      exit 1
    else
      echo -e "\n\e[33mMATCHING DIRECTORIES:\e[0m"
      i=1
      DIRECTORY_LIST=()
      for DIR in $DIRECTORIES; do
        echo "$i. $DIR"
        DIRECTORY_LIST+=("$DIR")
        ((i++))
      done
      echo -e "\n\e[33mEnter the number corresponding to the directory:\e[0m"
      read -p "" DIR_SELECTION
      if [[ "$DIR_SELECTION" -ge 1 && "$DIR_SELECTION" -le "${#DIRECTORY_LIST[@]}" ]]; then
        SELECTED_DIRECTORY="${DIRECTORY_LIST[$DIR_SELECTION - 1]}"
        break
      else
        echo -e "\n\e[31mError: Invalid selection. Please try again.\e[0m"
      fi
    fi
  done

  echo -e "\n\e[33mDIRECTORY SELECTED: \e[32m$SELECTED_DIRECTORY\e[0m"
}

# Main script logic
prompt_process_name
prompt_directory

# Prompt for memory limit
while true; do
  echo -e "\n\e[33mEnter the memory limit in kilobytes (e.g., 3000000 for 3 GB)\e[0m"
  read -p "" MEMORY_LIMIT
  if [[ "$MEMORY_LIMIT" =~ ^[0-9]+$ ]]; then
    MEMORY_LIMIT_GB=$(echo "scale=2; $MEMORY_LIMIT / (1024 * 1024)" | bc)
echo ""
#    printf "\033[33mMemory limit set to: %.2f GB.\033[0m\n" "$MEMORY_LIMIT_GB"

    echo -e "\n\e[33mMemory limit set to:\e[32m $MEMORY_LIMIT_GB GB.\e[0m"
    break
  else
    echo -e "\n\e[31mInvalid input. Please enter a numeric value.\e[0m"
  fi
done

# Print the selected directory
echo -e "\n\e[33mSELECTED DIRECTORY:\e[32m '$SELECTED_DIRECTORY'.\n\n\e[33mProceeding with the next steps....\e[0m"


# Form the path to save the script
SCRIPT_PATH="$SELECTED_DIRECTORY/memory_check.sh"

# Create the main script (overwrites the existing file)
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
# Version: 1.0.12

# Process name to monitor
PROCESS_NAME="$SELECTED_PROCESS"

# Memory limit in kilobytes
MEMORY_LIMIT_MB="$MEMORY_LIMIT"

# Check if the process is running
PROCESS_COUNT=\$(pgrep -c "\$PROCESS_NAME")

if [[ "\$PROCESS_COUNT" -eq 0 ]]; then
  echo -e "\$(date): Process \$PROCESS_NAME is not running. Skipping memory check.\n" >> /var/log/memory_check.log
  exit 0
fi

# Get the memory usage of the process (in KB)
MEMORY_USAGE=\$(ps --no-headers -o rss -p \$(pgrep "\$PROCESS_NAME") | awk '{sum+=\$1} END {print sum}')

# Check if the limit is exceeded
if [[ "\$MEMORY_USAGE" -gt "\$MEMORY_LIMIT_MB" ]]; then
  echo -e "\$(date): Memory limit \$MEMORY_USAGE KB exceeded for \$PROCESS_NAME. Restarting service...\n" >> /var/log/memory_check.log

  # Get the service name and restart it
  SERVICE_NAME=\$(cat /proc/\$(pidof "\$PROCESS_NAME")/cgroup | sed -n 's|.*/\([^.]*\)\.service|\1|p')

  if systemctl restart "\$SERVICE_NAME"; then
    echo -e "\$(date): Service \$SERVICE_NAME restarted successfully.\n" >> /var/log/mem_watch.log
  else
    echo -e "\$(date): Failed to restart \$SERVICE_NAME.\n" >> /var/log/mem_watch.log
  fi
fi
EOF

# Make the new script executable
#chmod +x "$SCRIPT_PATH"

# Information about the created script
echo -e "\n\e[33mScript created and saved in\e[32m $SCRIPT_PATH\e[0m"
echo -e "\n\e[33mLogs are stored in\e[32m /var/log/mem_watch.log\e[0m"
echo -e "\e[33mYou can check logs by using\e[32m cat /var/log/mem_watch.log\e[0m\n"
