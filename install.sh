#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")
UPDATE_URL="https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main/install.sh"
# ...
# ==========================================
# Universal Minecraft Server Installer
# Supports: PaperMC & NeoForge (ATM10)
# ==========================================

# ==========================================
# 1. FUNCTION DEFINITIONS
# ==========================================

papermc_update() {
    cat << 'EOF' > update.sh
    #!/bin/bash
    JAR_NAME="server.jar"
    PROJECT="paper"
    echo "🔎 Checking PaperMC API..."
    VERSION=$(curl -s https://api.papermc.io/v2/projects/${PROJECT} | jq -r '.versions[-1]')
    echo "   - Latest Version: $VERSION"
    BUILD=$(curl -s https://api.papermc.io/v2/projects/${PROJECT}/versions/${VERSION} | jq -r '.builds[-1]')
    echo "   - Latest Build:   #$BUILD"
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/${PROJECT}/versions/${VERSION}/builds/${BUILD}/downloads/${PROJECT}-${VERSION}-${BUILD}.jar"
    echo "⬇️  Downloading PaperMC $VERSION (Build #$BUILD)..."
    curl -o $JAR_NAME $DOWNLOAD_URL
    echo "✅ Update Complete!"
EOF
    chmod +x update.sh
    echo "✅ Created update.sh (PaperMC)"

}

# Global Command: 'mcserver'
setup_global_command() {
    local NAME="$1"
    local SERVER_PATH="$2"
    local REGISTRY="$HOME/.mc_registry"
    local BIN_PATH="/usr/local/bin/mcserver"
    local COMPLETION_PATH="/etc/bash_completion.d/mcserver"

    # --- SAFETY CHECK ---
    if [ -z "$NAME" ] || [ -z "$SERVER_PATH" ]; then
        echo "⚠️  Skipping registration: Name or Path is missing."
        return 1
    fi

    echo "--> Registering global command..."

    # 1. Create/Update Registry
    if [ ! -f "$REGISTRY" ]; then touch "$REGISTRY"; fi
    grep -v "^$NAME|" "$REGISTRY" | sed '/^$/d' > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
    echo "$NAME|$SERVER_PATH" >> "$REGISTRY"

    # 2. Create the Global Script
    cat << 'EOF' | sudo tee "$BIN_PATH" > /dev/null
#!/bin/bash
REGISTRY="$HOME/.mc_registry"
BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'; RED='\033[0;31m'

show_help() {
    echo -e "${BOLD}Minecraft Server Manager${NC}"
    echo -e "Usage: mcserver [COMMAND] [SERVER_NAME]"
    echo -e "  ${GREEN}list${NC}              List all registered servers."
    echo -e "  ${GREEN}<name>${NC}            Launch dashboard for <name>."
    echo -e "  ${GREEN}-h, --help${NC}        Show this help."
}

list_servers() {
    echo -e "\n${BOLD}📡 Registered Minecraft Servers:${NC}"
    echo -e "${GRAY}------------------------------------------------------------${NC}"
    printf "${CYAN}%-20s ${NC}| ${NC}%s\n" "SERVER NAME" "LOCATION"
    echo -e "${GRAY}------------------------------------------------------------${NC}"
    if [ ! -s "$REGISTRY" ]; then echo "   (No servers found)"; return; fi
    while IFS='|' read -r name path; do
        if [ -z "$name" ] || [ -z "$path" ]; then continue; fi
        printf "${GREEN}%-20s ${NC}| ${GRAY}%s${NC}\n" "$name" "$path"
    done < "$REGISTRY"
    echo ""
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then show_help; exit 0; fi
if [ "$1" == "list" ]; then list_servers; exit 0; fi

TARGET_NAME="$1"
if [ -z "$TARGET_NAME" ]; then
    list_servers
    echo -e "${BOLD}Select a server:${NC}"
    mapfile -t SERVERS < <(awk -F'|' '$1!="" {print $1}' "$REGISTRY")
    if [ ${#SERVERS[@]} -eq 0 ]; then exit 1; fi
    select s in "${SERVERS[@]}"; do
        if [ -n "$s" ]; then TARGET_NAME="$s"; break; else echo "Invalid."; fi
    done
fi

TARGET_PATH=$(grep "^$TARGET_NAME|" "$REGISTRY" | cut -d'|' -f2 | head -n 1)
if [ -z "$TARGET_PATH" ]; then echo -e "${RED}Error: Server '$TARGET_NAME' not found.${NC}"; exit 1; fi
if [ ! -d "$TARGET_PATH" ]; then echo -e "${RED}Error: Directory missing: $TARGET_PATH${NC}"; exit 1; fi

cd "$TARGET_PATH" || exit
[ -f "./dashboard.sh" ] && ./dashboard.sh || echo "Error: dashboard.sh missing."
EOF
    sudo chmod +x "$BIN_PATH"

    # 3. Create Bash Autocomplete Script
    echo "--> Installing tab-completion..."
    cat << 'EOF' | sudo tee "$COMPLETION_PATH" > /dev/null
_mcserver_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # 1. Get list of server names from registry (Column 1)
    #    Also add standard commands like 'list' and 'help'
    local servers=$(awk -F '|' '{print $1}' ~/.mc_registry 2>/dev/null)
    local commands="list help"

    # 2. Generate suggestions based on current word
    COMPREPLY=( $(compgen -W "${servers} ${commands}" -- ${cur}) )
    return 0
}
complete -F _mcserver_completion mcserver
EOF

    echo "✅ Server '$NAME' registered successfully (with auto-complete!)."
}

install_playit() {
    echo -e "--> Installing Playit.gg..."
    curl -L -s https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64 -o playit
    chmod +x playit
    sudo mv playit /usr/local/bin/playit

    # Detect the current user and home directory
    CURRENT_USER=$(whoami)
    USER_HOME=$HOME

    echo -e "--> Creating System Service (Running as: $CURRENT_USER)..."

    # NOTE: 'EOF' is NOT quoted here, so variables $CURRENT_USER and $USER_HOME will be filled in.
    cat << EOF | sudo tee /etc/systemd/system/playit.service > /dev/null
[Unit]
Description=Playit.gg Tunnel
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$USER_HOME
ExecStart=/usr/local/bin/playit
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable playit
    echo "✅ Playit.gg installed and configured for user: $CURRENT_USER!"
}

neoforge_update() {
    cat << 'EOF' > update.sh
    #!/bin/bash
    # NeoForge Updater & Cleaner

    echo "=========================================="
    echo "   NeoForge Server Updater"
    echo "=========================================="
    echo "⚠️  For ATM10, check the modpack version for the required NeoForge version."
    read -p "Enter NeoForge Version (e.g., 21.1.73): " NF_VERSION

    if [ -z "$NF_VERSION" ]; then
        echo "❌ Error: Version is required."
        exit 1
    fi

    INSTALLER="neoforge-${NF_VERSION}-installer.jar"
    URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/${NF_VERSION}/${INSTALLER}"

    echo "⬇️  Downloading installer: $INSTALLER..."
    wget -O installer.jar "$URL"

    if [ ! -f installer.jar ]; then
        echo "❌ Error: Download failed. Check the version number."
        exit 1
    fi

    echo "⚙️  Running NeoForge Installer..."
    java -jar installer.jar --installServer

    # === CLEANUP & CONFIGURATION ===
    echo "🧹 Cleaning up clutter..."
    rm installer.jar
    rm installer.jar.log 2>/dev/null
    rm run.bat 2>/dev/null  # Remove Windows junk

    # === RAM SYNC ===
    # We grab the RAM variable from the main script if possible, or default to 4G
    # Note: When running this update.sh standalone later, RAM might not be set.
    # So we check if user_jvm_args.txt exists, if not we create it.

    if [ ! -f "user_jvm_args.txt" ]; then
        echo "-Xms4G" > user_jvm_args.txt
        echo "-Xmx4G" >> user_jvm_args.txt
        echo "📝 Created user_jvm_args.txt with default 4G RAM."
    else
        echo "✅ user_jvm_args.txt preserved."
    fi

    echo "✅ NeoForge updated to $NF_VERSION."
EOF
    chmod +x update.sh
    echo "✅ Created update.sh (NeoForge + Auto-Cleaner)"

}

create_stop_script() {
    cat << 'EOF' > stop.sh#!/bin/bash
# Settings
SCREEN_NAME="minecraft"
MAX_WAIT=30

echo "🛑 Sending stop command to Minecraft server..."

# 1. Send the graceful stop command to the Minecraft console
screen -S $SCREEN_NAME -p 0 -X stuff "stop^M"

echo "⏳ Waiting for server to save and close (max $MAX_WAIT seconds)..."

# 2. Wait loop
# We wait to give the server time to save chunks to disk.
# If the screen closes itself early, great! If not, we wait the full duration.
count=0
while screen -list | grep -q "$SCREEN_NAME"; do
    if [ $count -ge $MAX_WAIT ]; then
        echo "⚠️  Time is up! The screen session is still active."
        break
    fi
    sleep 1
    count=$((count+1))
    echo -ne "Waiting... $count/$MAX_WAIT\r"
done
echo "" # New line after the counter

# 3. Handle the remaining screen session
if screen -list | grep -q "$SCREEN_NAME"; do
    echo "🧹 Screen session is still running (likely a restart loop or shell)."
    echo "✨ Terminating the screen session now..."

    # Send the 'quit' command to screen, which kills the session cleanly
    screen -S $SCREEN_NAME -X quit
else
    echo "✅ Server and screen session stopped gracefully!"
fi
EOF
    chmod +x stop.sh
    echo "✅ stop.sh created (With Timeout)."
}

create_start_script() {
    cat << 'EOF' > start.sh
#!/bin/bash
SERVER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SERVER_DIR"

# 1. CLEANUP GHOST SCREENS
# This removes "Dead" sockets that confuse the system
screen -wipe >/dev/null 2>&1

# 2. DETECT SETTINGS
DETECTED_SCREEN=$(screen -ls | grep -E "minecraft|mcserver|Forge|Paper" | awk '{print $1}' | cut -d. -f2 | head -n 1)
SCREEN_NAME="${DETECTED_SCREEN:-minecraft}"

# 3. CHECK IF RUNNING
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "⚠️  Server is already running in screen: $SCREEN_NAME"
    exit 1
fi

echo "🚀 Starting Server ($SCREEN_NAME)..."

# 4. DETERMINE START COMMAND
# If run.sh exists (NeoForge/Modpacks), use it. Otherwise use Java.
if [ -f "run.sh" ]; then
    chmod +x run.sh
    START_CMD="./run.sh"
else
    # Default RAM if not detected
    RAM="4G"
    if [ -f "user_jvm_args.txt" ]; then
        RAM=$(grep -o '-Xmx[0-9]\+[GM]' user_jvm_args.txt | head -1 | sed 's/-Xmx//')
    fi
    START_CMD="java -Xms$RAM -Xmx$RAM -jar server.jar nogui"
fi

# 5. LAUNCH SCREEN
# We launch the screen here. The script finishes, but screen stays in background.
/usr/bin/screen -dmS "$SCREEN_NAME" /bin/bash -c "$START_CMD; exec bash"

echo "✅ Server started in background."
EOF
    chmod +x start.sh
    echo "✅ start.sh created (Smart Mode)."
}

create_restart_script() {
    cat << EOF > restart.sh
    #!/bin/bash
    echo "🔄 Rebooting Server..."
    ./stop.sh
    sleep 2
    ./start.sh
    echo "✅ Server restarted successfully."
EOF
    chmod +x restart.sh
    echo "✅ Created restart.sh"
}

create_forcekill_script() {
    cat << 'EOF' > forcekill.sh
#!/bin/bash
SERVER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🔪 Surgical Force Kill..."

# 1. Find Java running ONLY in this directory
# We search for the folder path in the java command arguments
JAVA_PID=$(pgrep -f "java.*$SERVER_DIR")

if [ -n "$JAVA_PID" ]; then
    echo "   - Killing Server Process (PID: $JAVA_PID)"
    kill -9 "$JAVA_PID" >/dev/null 2>&1
else
    echo "   - No specific server process found."
fi

# 2. Cleanup Screen Session
DETECTED_SCREEN=$(screen -ls | grep -E "minecraft|mcserver|Forge|Paper" | awk '{print $1}' | cut -d. -f2 | head -n 1)
if [ -z "$DETECTED_SCREEN" ]; then DETECTED_SCREEN=$(screen -ls | grep -P '^\t\d+\.' | awk '{print $1}' | cut -d. -f2 | head -n 1); fi
SCREEN_NAME="${DETECTED_SCREEN:-minecraft}"

if screen -list | grep -q "$SCREEN_NAME"; then
    echo "   - Wiping Screen Session: $SCREEN_NAME"
    screen -X -S "$SCREEN_NAME" quit >/dev/null 2>&1
fi

echo "✅ Done."
EOF
    chmod +x forcekill.sh
    echo "✅ forcekill.sh created (Surgical Mode)."
}

create_uninstall_script() {
    cat << 'EOF' > uninstall.sh
#!/bin/bash
TARGET_DIR="$(pwd)"
REGISTRY="$HOME/.mc_registry"

# 1. Confirmation
echo "⚠️  WARNING: This will PERMANENTLY DELETE:"
echo "   $TARGET_DIR"
echo "------------------------------------------"
read -p "Type 'delete' to confirm: " CONFIRM
if [ "$CONFIRM" != "delete" ]; then echo "❌ Cancelled."; exit 1; fi

echo "🗑️  Cleaning up..."

# 2. Surgical Process Kill (Only kills Java running in THIS folder)
# We look for a Java process whose arguments include this directory path
JAVA_PID=$(pgrep -f "java.*$TARGET_DIR")
if [ -n "$JAVA_PID" ]; then
    echo "   - Killing server process (PID: $JAVA_PID)..."
    kill -9 "$JAVA_PID" >/dev/null 2>&1
fi

# 3. Screen Session Cleanup
# Detect the screen name just like the dashboard does
DETECTED_SCREEN=$(screen -ls | grep -E "minecraft|mcserver|Forge|Paper" | awk '{print $1}' | cut -d. -f2 | head -n 1)
if [ -n "$DETECTED_SCREEN" ]; then
    screen -X -S "$DETECTED_SCREEN" quit >/dev/null 2>&1
    echo "   - Closed Screen session."
fi

# 4. Remove from Cron (Auto-start/Auto-restart)
(crontab -l 2>/dev/null | grep -vF "$TARGET_DIR") | crontab -
echo "   - Removed automation schedules."

# 5. Remove from Registry
if [ -f "$REGISTRY" ]; then
    awk -F '|' -v target="$TARGET_DIR" '$2 != target' "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
    echo "   - Removed from Global Registry."
fi

# 6. Delete Files
if [ "$TARGET_DIR" == "/" ] || [ -z "$TARGET_DIR" ]; then
    echo "❌ Safety Stop: Root directory detected. Aborting delete."; exit 1
fi

echo "   - Deleting files..."
cd ..
rm -rf "$TARGET_DIR"

echo "✅ Uninstall Complete."
EOF
    chmod +x uninstall.sh
    echo "✅ uninstall.sh created."
}

# Modpack Installer
create_modpack_installer() {
    local TARGET_DIR="$1"
    if [ -z "$TARGET_DIR" ]; then TARGET_DIR="."; fi

    echo -e "--> Creating 'install_modpack.sh' in ${TARGET_DIR}..."

    cat << 'EOF' > "${TARGET_DIR}/install_modpack.sh"
#!/bin/bash
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
echo -e "${CYAN}=== CurseForge/NeoForge Pack Installer ===${NC}"

[ -f "./forcekill.sh" ] && ./forcekill.sh

# 1. Get Link
if [ -z "$1" ]; then
    echo -e "Paste the ${GREEN}download link${NC} (zip):"
    read -r DOWNLOAD_URL
else
    DOWNLOAD_URL=$1
fi

if [ -z "$DOWNLOAD_URL" ]; then echo "No URL."; exit 1; fi

# 2. Download & Unzip
echo "--> Downloading..."
wget -O server_pack.zip "$DOWNLOAD_URL" || { echo "Download failed"; exit 1; }

echo "--> Extracting..."
if ! command -v unzip &> /dev/null; then sudo apt-get install unzip -y; fi
unzip -o server_pack.zip
rm server_pack.zip

# 3. Flatten Nested Folders
DIR_COUNT=$(ls -d */ 2>/dev/null | wc -l)
FILE_COUNT=$(ls -p | grep -v / | wc -l)

if [ "$DIR_COUNT" -eq 1 ] && [ "$FILE_COUNT" -le 2 ]; then
    SUBFOLDER=$(ls -d */)
    SUBFOLDER=${SUBFOLDER%/}
    echo "--> Moving files out of subfolder: $SUBFOLDER"
    mv "$SUBFOLDER"/* . 2>/dev/null
    mv "$SUBFOLDER"/.* . 2>/dev/null
    rmdir "$SUBFOLDER"
fi

# 4. Permissions
chmod +x *.sh 2>/dev/null
echo "eula=true" > eula.txt

# Check for Installer
if [ ! -f "run.sh" ] && [ ! -f "start.sh" ]; then
    INSTALLER_JAR=$(ls *installer.jar 2>/dev/null | head -n 1)
    if [ -n "$INSTALLER_JAR" ]; then
        echo "Found Installer Jar: $INSTALLER_JAR"
        echo "Run: java -jar $INSTALLER_JAR --installServer"
    fi
fi
echo -e "${GREEN}Done!${NC}"
EOF
    chmod +x "${TARGET_DIR}/install_modpack.sh"
    echo "✅ Helper script created successfully."
}

# create a backup script
create_backup_system() {
    local TARGET_DIR="$1"

    # Chekcs if unzip is installed and installs it if its missing.
    if ! command -v unzip &> /dev/null; then
    echo -e "${CYAN}--> 'unzip' is missing. Installing it now...${NC}"
    sudo apt-get update -qq && sudo apt-get install unzip -y
    # ... checks if it failed ...
    fi

    # Default to current directory if not provided
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="."
    fi

    # 1. Get Absolute Path of the Target Directory
    pushd "$TARGET_DIR" > /dev/null
    local ABS_SERVER_DIR=$(pwd)
    popd > /dev/null

    echo -e "--> Creating 'backup.sh' in ${TARGET_DIR}..."

    # 2. Generate the Script
    cat << 'EOF' > "${TARGET_DIR}/backup.sh"
#!/bin/bash
# --- Auto-Generated Backup Script ---

# CONFIGURATION
SCREEN_NAME="mcserver"
SERVER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DIR="${SERVER_DIR}/backups"
TARGET_FOLDER="world"

# RETENTION SETTINGS
RETENTION_DAYS=7

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="backup-${TIMESTAMP}.tar.gz"

# 1. Prepare
mkdir -p "$BACKUP_DIR"
cd "$SERVER_DIR" || exit 1

# 2. Notify & Stop Saves
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "--> Server is running. Suspending saves..."
    screen -S "$SCREEN_NAME" -p 0 -X stuff "say §e[Backup] Starting backup... (Every 4 Hours)\n"
    screen -S "$SCREEN_NAME" -p 0 -X stuff "save-off\n"
    screen -S "$SCREEN_NAME" -p 0 -X stuff "save-all\n"
    sleep 5
else
    echo "--> Server not running. Backing up offline files."
fi

# 3. Compress
echo "--> Compressing to $BACKUP_NAME..."
# Exclude backups folder to prevent infinite loop
tar --exclude='./backups' -czf "${BACKUP_DIR}/${BACKUP_NAME}" .

# 4. Resume Saves
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "--> Re-enabling saves..."
    screen -S "$SCREEN_NAME" -p 0 -X stuff "save-on\n"
    screen -S "$SCREEN_NAME" -p 0 -X stuff "say §a[Backup] Complete!\n"
fi

# 5. Cleanup
echo "--> Removing backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
echo "✅ Done."
EOF

    chmod +x "${TARGET_DIR}/backup.sh"

    # 3. Add to Crontab (Every 4 Hours)
    echo "--> Registering Backup Cron Job..."
    # Cron syntax: Minute(0) Hour(*/4) Day(*) Month(*) Weekday(*)
    local CRON_CMD="0 */4 * * * /bin/bash ${ABS_SERVER_DIR}/backup.sh >/dev/null 2>&1"

    (crontab -l 2>/dev/null | grep -F "${ABS_SERVER_DIR}/backup.sh") && echo "⚠️ Cron backup already exists." || {
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "✅ Backup scheduled for every 4 hours."
    }
}

# 3. Dashboard Installer
install_dashboard() {
    # We use double quotes here so $UPDATE_URL is expanded NOW,
    # but we escape \$ variables so they are written literally to the file.
    cat << EOF > dashboard.sh
#!/bin/bash
SERVER_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
UPDATE_URL="$UPDATE_URL"

# --- STYLING ---
BOLD=\$(tput bold); NORM=\$(tput sgr0)
RED=\$(tput setaf 1); GREEN=\$(tput setaf 2); YELLOW=\$(tput setaf 3)
BLUE=\$(tput setaf 4); CYAN=\$(tput setaf 6); WHITE=\$(tput setaf 7); GRAY=\$(tput setaf 8); MAGENTA=\$(tput setaf 5)
UI_WIDTH=60; UI_HEIGHT=22

# --- FUNCTIONS ---
detect_screen() {
    DETECTED_SCREEN=\$(screen -ls | grep -E "minecraft|mcserver|Forge|Paper" | awk '{print \$1}' | cut -d. -f2 | head -n 1)
    if [ -z "\$DETECTED_SCREEN" ]; then DETECTED_SCREEN=\$(screen -ls | grep -P '^\t\d+\.' | awk '{print \$1}' | cut -d. -f2 | head -n 1); fi
    SCREEN_NAME="\${DETECTED_SCREEN:-minecraft}"
}

find_java_pid() {
    JAVA_PID=""
    for pid in \$(pgrep -u "\$(whoami)" java); do
        PROCESS_DIR=\$(readlink -f /proc/\$pid/cwd)
        if [[ "\$PROCESS_DIR" == "\$SERVER_DIR" ]]; then JAVA_PID=\$pid; break; fi
    done
}

check_autostart() {
    if crontab -l 2>/dev/null | grep -F "\$SERVER_DIR" | grep -q "@reboot"; then
        AUTOSTART_MSG="\${GREEN}\${BOLD}ON\${NORM}"; AUTOSTART_STATE="on"
    else
        AUTOSTART_MSG="\${RED}\${BOLD}OFF\${NORM}"; AUTOSTART_STATE="off"
    fi
}

toggle_autostart() {
    if [ -f "\$SERVER_DIR/run.sh" ]; then START_SCRIPT="run.sh"; else START_SCRIPT="start.sh"; fi
    CRON_CMD="@reboot /usr/bin/screen -dmS \$SCREEN_NAME /bin/bash \$SERVER_DIR/\$START_SCRIPT"

    if [ "\$AUTOSTART_STATE" == "on" ]; then
        (crontab -l 2>/dev/null | grep -vF "\$SERVER_DIR/\$START_SCRIPT") | crontab -
        echo "✅ Auto-start disabled."
    else
        (crontab -l 2>/dev/null; echo "\$CRON_CMD") | crontab -
        echo "✅ Auto-start enabled."
    fi
}

check_autorestart() {
    EXISTING_CRON=\$(crontab -l 2>/dev/null | grep -F "\$SERVER_DIR/restart.sh")
    if [ -n "\$EXISTING_CRON" ]; then
        MIN=\$(echo "\$EXISTING_CRON" | awk '{print \$1}')
        HOUR=\$(echo "\$EXISTING_CRON" | awk '{print \$2}')
        printf -v PRETTY_TIME "%02d:%02d" "\$HOUR" "\$MIN"
        AUTORESTART_MSG="\${GREEN}\${BOLD}ON (\$PRETTY_TIME)\${NORM}"; AUTORESTART_STATE="on"
    else
        AUTORESTART_MSG="\${RED}\${BOLD}OFF\${NORM}"; AUTORESTART_STATE="off"
    fi
}

toggle_autorestart() {
    if [ "\$AUTORESTART_STATE" == "on" ]; then
        (crontab -l 2>/dev/null | grep -vF "\$SERVER_DIR/restart.sh") | crontab -
        echo "✅ Daily restart disabled."
    else
        echo "-----------------------------------"
        echo "⏰ Configure Daily Auto-Restart"
        echo "-----------------------------------"
        read -p "Enter Hour (0-23): " IN_HOUR
        read -p "Enter Minute (0-59): " IN_MIN

        if ! [[ "\$IN_HOUR" =~ ^[0-9]+$ ]] || [ "\$IN_HOUR" -lt 0 ] || [ "\$IN_HOUR" -gt 23 ]; then echo "❌ Invalid Hour."; return; fi
        if ! [[ "\$IN_MIN" =~ ^[0-9]+$ ]] || [ "\$IN_MIN" -lt 0 ] || [ "\$IN_MIN" -gt 59 ]; then echo "❌ Invalid Minute."; return; fi

        CRON_CMD="\$IN_MIN \$IN_HOUR * * * /bin/bash \$SERVER_DIR/restart.sh >/dev/null 2>&1"
        (crontab -l 2>/dev/null; echo "\$CRON_CMD") | crontab -
        printf "✅ Restart scheduled for %02d:%02d daily.\n" "\$IN_HOUR" "\$IN_MIN"
    fi
}

change_ram() {
    clear
    echo "-----------------------------------"
    echo "🧠 Change RAM Allocation"
    echo "-----------------------------------"
    TOTAL_MEM_GB=\$(free -g | awk '/^Mem:/{print \$2}')
    echo "💻 System Memory: \${TOTAL_MEM_GB}GB"
    echo ""
    read -p "Enter new RAM amount (in GB): " NEW_RAM
    if ! [[ "\$NEW_RAM" =~ ^[0-9]+$ ]]; then echo "❌ Invalid number."; read -p "Press Enter..."; return; fi

    if [ "\$NEW_RAM" -gt "\$TOTAL_MEM_GB" ]; then
        echo ""; echo "❌ Error: You only have \${TOTAL_MEM_GB}GB of RAM!"; echo "   You cannot allocate \${NEW_RAM}GB."; read -p "Press Enter..."; return
    fi

    SAFE_LIMIT=\$(( TOTAL_MEM_GB - 1 ))
    if [ "\$NEW_RAM" -gt "\$SAFE_LIMIT" ]; then
        echo ""; echo "⚠️  CRITICAL WARNING: You are leaving less than 1GB for the OS!"; echo "   This will likely crash your server."; read -p "Type 'force' to do it anyway: " CONFIRM
        if [ "\$CONFIRM" != "force" ]; then echo "Cancelled."; read -p "Press Enter..."; return; fi
    fi

    if [ "\$NEW_RAM" -gt 12 ]; then
        echo ""; echo "⚠️  Performance Warning: Allocating >12GB can cause Lag Spikes."; read -p "Press Enter to continue..."
    fi

    echo ""; echo "--> Applying \${NEW_RAM}GB allocation..."
    if [ -f "user_jvm_args.txt" ]; then
        grep -v "-Xms" user_jvm_args.txt | grep -v "-Xmx" > user_jvm_args.tmp
        echo "-Xms\${NEW_RAM}G" >> user_jvm_args.tmp
        echo "-Xmx\${NEW_RAM}G" >> user_jvm_args.tmp
        mv user_jvm_args.tmp user_jvm_args.txt
        echo "✅ Updated user_jvm_args.txt"
    fi
    if [ -f "start.sh" ]; then
        sed -i "s/-Xms[0-9]*[MG]/-Xms\${NEW_RAM}G/g" start.sh
        sed -i "s/-Xmx[0-9]*[MG]/-Xmx\${NEW_RAM}G/g" start.sh
        echo "✅ Updated start.sh"
    fi
    echo ""; echo "🎉 Success! Restart the server to apply changes."; read -p "Press Enter..."
}

perform_update() {
    clear
    echo "-----------------------------------"
    echo "🔄 Auto-Updater"
    echo "-----------------------------------"
    echo "Downloading latest installer from Git..."

    if curl -L -s -f -o install.sh "\$UPDATE_URL"; then
        chmod +x install.sh
        echo "Running update..."
        ./install.sh --refresh
        rm install.sh
        echo "-----------------------------------"
        echo "✅ Update Complete. Restarting Dashboard..."
        sleep 2
        exec ./dashboard.sh
    else
        echo "❌ Update Failed!"
        echo "   Could not download the file. Check your UPDATE_URL."
        echo "   Target: \$UPDATE_URL"
        read -p "Press Enter..."
    fi
}

get_server_stats() {
    detect_screen; check_autostart; check_autorestart
    if screen -list | grep -q "\$SCREEN_NAME"; then
        STATUS="\${GREEN}\${BOLD}ONLINE\${NORM}"
        find_java_pid
        if [ -n "\$JAVA_PID" ]; then
            STATS=\$(ps -p \$JAVA_PID -o %cpu=,rss=)
            CPU_RAW=\$(echo "\$STATS" | awk '{print \$1}')
            RAM_KB=\$(echo "\$STATS" | awk '{print \$2}')
            RAM_MB=\$((RAM_KB / 1024))
            MAX_RAM_VISUAL=12288
            RAM_PERCENT=\$(( (RAM_MB * 100) / MAX_RAM_VISUAL ))
            [[ \$RAM_PERCENT -gt 100 ]] && RAM_PERCENT=100
            R_FILL=\$(( (RAM_PERCENT * 18) / 100 )); R_EMPTY=\$(( 18 - R_FILL ))
            RAM_BAR=""; for ((i=0; i<R_FILL; i++)); do RAM_BAR="\${RAM_BAR}#"; done; for ((i=0; i<R_EMPTY; i++)); do RAM_BAR="\${RAM_BAR}."; done
            CORES=\$(nproc)
            CPU_INT=\${CPU_RAW%.*}
            if [ "\$CORES" -gt 1 ]; then CPU_NORMALIZED=\$(( CPU_INT / CORES )); else CPU_NORMALIZED=\$CPU_INT; fi
            C_FILL=\$(( (CPU_NORMALIZED * 18) / 100 )); C_EMPTY=\$(( 18 - C_FILL ))
            [[ \$C_FILL -gt 18 ]] && C_FILL=18; [[ \$C_FILL -lt 0 ]] && C_FILL=0; [[ \$C_EMPTY -lt 0 ]] && C_EMPTY=0
            CPU_BAR=""; for ((i=0; i<C_FILL; i++)); do CPU_BAR="\${CPU_BAR}#"; done; for ((i=0; i<C_EMPTY; i++)); do CPU_BAR="\${CPU_BAR}."; done
            STATS_TEXT_1="\${WHITE}RAM:\${NORM} [\${CYAN}\${RAM_BAR}\${NORM}] \${WHITE}\${RAM_MB}MB\${NORM}"
            STATS_TEXT_2="\${WHITE}CPU:\${NORM} [\${GREEN}\${CPU_BAR}\${NORM}] \${WHITE}\${CPU_NORMALIZED}%\${NORM}"
            PID_TEXT="\${GRAY}(PID: \$JAVA_PID)\${NORM}"
        else
            STATUS="\${YELLOW}\${BOLD}STARTING\${NORM}"; STATS_TEXT_1="\${YELLOW}Waiting for Java...\${NORM}"; STATS_TEXT_2=""; PID_TEXT=""
        fi
    else
        STATUS="\${RED}\${BOLD}OFFLINE\${NORM}"; STATS_TEXT_1="\${GRAY}Server is stopped.\${NORM}"; STATS_TEXT_2=""; PID_TEXT=""
    fi
}

draw_ui() {
    get_server_stats
    TERM_COLS=\$(tput cols); TERM_LINES=\$(tput lines)
    PAD_LEFT=\$(( (TERM_COLS - UI_WIDTH) / 2 )); PAD_TOP=\$(( (TERM_LINES - UI_HEIGHT) / 2 ))
    [[ \$PAD_LEFT -lt 0 ]] && PAD_LEFT=0; [[ \$PAD_TOP -lt 0 ]] && PAD_TOP=0

    print_line() { tput cup \$((PAD_TOP + \$1)) \$PAD_LEFT; echo -e "\$2"; }

    print_line 0  "\${BLUE}==Version 1.0===============================================\${NORM}"
    print_line 1  "         👾  \${BOLD}MINECRAFT SERVER DASHBOARD\${NORM}  👾"
    print_line 2  "\${BLUE}============================================================\${NORM}"
    print_line 3  " Path:      \${GRAY}\${SERVER_DIR}\${NORM}"
    print_line 4  " Session:   \${CYAN}\${SCREEN_NAME}\${NORM} \$PID_TEXT"
    print_line 5  " Status:    \$STATUS         ⏰ On Boot: \$AUTOSTART_MSG"
    print_line 6  "                           🔄 Daily:   \$AUTORESTART_MSG"
    print_line 7  ""
    print_line 8  " \$STATS_TEXT_1"
    print_line 9  " \$STATS_TEXT_2"
    print_line 10 ""
    print_line 11 "\${BLUE}------------------------------------------------------------\${NORM}"
    print_line 12 "   \${GREEN}[1]\${NORM} ▶ Start Server      \${YELLOW}[6]\${NORM} 📦 Install Modpack"
    print_line 13 "   \${RED}[2]\${NORM} ■ Stop Server       \${YELLOW}[7]\${NORM} 🌐 Playit.gg Status"
    print_line 14 "   \${CYAN}[3]\${NORM} > Open Console      \${MAGENTA}[8]\${NORM} ⏰ Toggle On-Boot"
    print_line 15 "   \${YELLOW}[4]\${NORM} 💾 Force Backup     \${MAGENTA}[9]\${NORM} 🔄 Schedule Restart"
    print_line 16 "   \${RED}[5]\${NORM} ❌ Uninstall        \${CYAN}[0]\${NORM} 🧠 Change RAM"
    print_line 17 "   \${RED}[K]\${NORM} ❌ Forcekill"
    print_line 18 "   \${BLUE}[U]\${NORM} 🔄 Update Tools"
    print_line 19 "\${BLUE}============================================================\${NORM}"
    print_line 20 "   \${RED}[Q]\${NORM} Quit"
    tput cup \$TERM_LINES \$TERM_COLS
}

# --- MAIN LOOP ---
tput smcup; tput civis; stty -echo
trap "tput rmcup; tput cnorm; stty echo; exit" EXIT
clear

while true; do
    draw_ui
    read -t 1 -n 1 -s key
    # INPUT SANITIZER
    if [[ "\$key" == \$'\e' ]]; then read -t 0.001 -n 3 -s trash; key=""; fi

    if [ -n "\$key" ]; then
        case \$key in
            1) clear; echo -e "\n\${GREEN}--> Starting...\${NORM}"; if [ -f "./start.sh" ]; then ./start.sh; elif [ -f "./run.sh" ]; then ./run.sh; fi; read -p "Press Enter..."; clear ;;
            2) clear; echo -e "\n\${RED}--> Stopping...\${NORM}"; ./stop.sh; read -p "Press Enter..."; clear ;;
            3) tput cnorm; stty echo; clear; echo -e "\${CYAN}--> Console... (Ctrl+A, D to exit)\${NORM}"; sleep 1; screen -r "\$SCREEN_NAME"; tput civis; stty -echo; clear ;;
            # FIX: Added stty echo/tput cnorm to all interactive options below
            4) tput cnorm; stty echo; clear; echo -e "\n\${YELLOW}--> Backup...\${NORM}"; [ -f "./backup.sh" ] && ./backup.sh; read -p "Done."; tput civis; stty -echo; clear ;;
            5) tput cnorm; stty echo; clear; echo -e "\n\${RED}--> Uninstalling...\${NORM}"; [ -f "./uninstall.sh" ] && ./uninstall.sh; read -p "Press Enter..."; tput civis; stty -echo; clear ;;
            6) tput cnorm; stty echo; clear; [ -f "./install_modpack.sh" ] && ./install_modpack.sh; read -p "Done."; tput civis; stty -echo; clear ;;
            7) clear; echo -e "\n\${CYAN}--> Playit.gg\${NORM}"; sudo systemctl status playit --no-pager; read -p "Done."; clear ;;
            8) clear; echo -e "\n\${MAGENTA}--> Toggling On-Boot Start...\${NORM}"; toggle_autostart; read -p "Done."; clear ;;
            9) tput cnorm; stty echo; clear; echo -e "\n\${MAGENTA}--> Configuring Daily Restart...\${NORM}"; toggle_autorestart; read -p "Press Enter..."; tput civis; stty -echo; clear ;;
            0) tput cnorm; stty echo; change_ram; tput civis; stty -echo; clear ;;
            k|K) tput cnor; stty echo; ./forcekill.sh; read -p "Done."; clear;;
            u|U) tput cnorm; stty echo; perform_update ;;
            q|Q) clear; exit 0 ;;
        esac
    fi
done
EOF
    chmod +x dashboard.sh
    echo "✅ Dashboard installed."
}

configure_autostart_service() {
    echo "⚙️  Configuring Auto-Start Service..."

    SERVICE_NAME="minecraft-$(basename "$(pwd)")"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    CURRENT_USER="$(whoami)"
    SERVER_DIR="$(pwd)"

    # Write the service file
    cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Minecraft Server: $(basename "$SERVER_DIR")
After=network.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_USER
Type=forking
WorkingDirectory=$SERVER_DIR

# START: Just run the script (which handles the screen creation)
ExecStart=/bin/bash $SERVER_DIR/start.sh

# STOP: Send safe stop command to console
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop\015"'
ExecStop=/bin/sleep 10

# RESTART: Auto-restart if it crashes
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Reload and Enable
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    echo "✅ Auto-start updated (No-Inception Mode)."
}


install_minecraft_server() {
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: 'jq' is not installed."
        return 1
    fi

    echo "=========================================="
    echo "   Minecraft Server Selection"
    echo "=========================================="
    echo "1) PaperMC (Plugins, High Performance)"
    echo "2) NeoForge (Mods, ATM10, etc.)"
    echo "=========================================="
    read -p "Select server type [1 or 2]: " SERVER_TYPE

    # === PAPERMC ===
    if [ "$SERVER_TYPE" == "1" ]; then
        echo "--- PaperMC Selected ---"
        papermc_update
        # Run the update script we just made
        ./update.sh

    # === NEOFORGE ===
    elif [ "$SERVER_TYPE" == "2" ]; then
        echo "--- NeoForge Selected ---"
        neoforge_update
        create_modpack_installer
        # Run the update script
        ./update.sh

        # 🟢 NEW: Force-write the RAM settings immediately after install
        echo "-Xms$RAM" > user_jvm_args.txt
        echo "-Xmx$RAM" >> user_jvm_args.txt
        echo "✅ RAM set to $RAM in user_jvm_args.txt"

        # Ensure run.sh is executable
        if [ -f "run.sh" ]; then
            chmod +x run.sh
        fi
     fi
    read -p "Install playit for port tunneling? (y/n): " PLAYIT_CHOICE
    if [[ "$PLAYIT_CHOICE" =~ ^[Yy]$ ]]; then
        install_playit
    fi
    # Auto-EULA
    read -p "Auto-accept minecraft EULA? (y/n): " EULA_CHOICE
    if [[ "$EULA_CHOICE" =~ ^[Yy]$ ]]; then
        echo "eula=true" > eula.txt
        echo "✅ EULA accepted."
    fi

    # Generate all helper scripts now that we know the type
    create_start_script
    create_stop_script
    create_restart_script
    create_forcekill_script
    create_uninstall_script
    create_backup_system
    install_dashboard
    configure_autostart_service
    setup_global_command "$(basename "$(pwd)")" "$(pwd)"
}

# ==========================================
# 2. MAIN EXECUTION
# ==========================================
# ==========================================
# 4. REFRESH / UPDATE MODE
# ==========================================

if [ "$1" == "--refresh" ]; then
    echo "🔄 Update Mode: Detecting configuration..."

    # 1. Detect RAM from existing files (Updated for compatibility)
    if [ -f "user_jvm_args.txt" ]; then
        # NeoForge: Find -Xmx4G, then strip '-Xmx'
        RAM=$(grep -o '-Xmx[0-9]\+[GM]' user_jvm_args.txt | head -1 | sed 's/-Xmx//')
    elif [ -f "start.sh" ]; then
        # Paper: Find -Xms4G, then strip '-Xms'
        RAM=$(grep -o '-Xms[0-9]\+[GM]' start.sh | head -1 | sed 's/-Xms//')
    fi

    if [ -z "$RAM" ]; then
        RAM="4G"
        echo "⚠️  Could not detect RAM. Defaulting to 4G."
    else
        echo "   - Detected RAM: $RAM"
    fi

    # 2. Detect Server Type
    if [ -f "run.sh" ]; then
        echo "   - Detected Type: NeoForge"
        SERVER_TYPE="2"
        chmod +x run.sh
    else
        echo "   - Detected Type: Paper/Standard"
        SERVER_TYPE="1"
        JAR_FILE="server.jar"
    fi

    # 3. Regenerate All Scripts
    echo "📦 Regenerating tools..."
    create_start_script
    create_stop_script
    create_restart_script
    create_forcekill_script
    create_uninstall_script
    create_backup_system
    configure_autostart_service
    install_dashboard
    setup_global_command "$(basename "$(pwd)")" "$(pwd)"

    echo "✅ Scripts updated successfully!"
    exit 0
fi

echo "🛠️  Initializing Setup..."

# ==========================================
# Directory Setup
# ==========================================
echo "📂 Directory Setup"
read -p "Name of new server folder (press Enter to use current folder): " DIR_NAME

if [ ! -z "$DIR_NAME" ]; then
    echo "Creating folder '$DIR_NAME'..."
    mkdir -p "$DIR_NAME"
    cd "$DIR_NAME" || exit

    echo "✅ Switched to $(pwd)"
else
    DEFAULT_DIR=mc-server
    mkdir -p "$DEFAULT_DIR"
    cd "$DEFAULT_DIR" || exit
    echo "⚠️  Installing in CURRENT directory: $DEFAULT_DIR"
fi
echo ""

# Install Dependencies
echo "📦 Installing system packages (Java 21, Screen, JQ, Curl)..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jre-headless screen jq curl || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre screen jq curl

echo "✅ System ready."
echo ""

# RAM Setup
read -p "Enter RAM amount (e.g., 4G): " RAM_INPUT
if [ -z "$RAM_INPUT" ]; then
    RAM="4G"
elif [[ "$RAM_INPUT" =~ ^[0-9]+$ ]]; then
    RAM="${RAM_INPUT}G"
else
    RAM="$RAM_INPUT"
fi

# Global Variables
SCREEN_NAME="minecraft"
JAR_FILE="server.jar" # Default for Paper, NeoForge uses run.sh wrapper

echo ""
echo "📝 Configuration saved: RAM=$RAM"
echo ""

# Run the Main Installer Logic
install_minecraft_server

echo ""
echo "🎉 Installation Complete!"
echo "👉 Use mcserver $(basename "$(pwd)") to launch the server dashboard."

# ==========================================
# Self-Cleanup
# ==========================================
echo "🧹 Cleaning up installer file..."
rm -- "$SCRIPT_PATH"
