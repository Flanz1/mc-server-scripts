#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")
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

# ==========================================
# 🌍 Global Command: 'mcserver'
# ==========================================
setup_global_command() {
    local NAME="$1"
    local PATH="$2"
    local REGISTRY="$HOME/.mc_registry"
    local BIN_PATH="/usr/local/bin/mcserver"

    echo "--> Registering global command..."

    # 1. Create/Update the Registry File
    # Format: SERVER_NAME|SERVER_PATH
    if [ ! -f "$REGISTRY" ]; then touch "$REGISTRY"; fi

    # Remove old entry if it exists (to avoid duplicates), then append new one
    grep -v "^$NAME|" "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
    echo "$NAME|$PATH" >> "$REGISTRY"

    # 2. Create the Global Script (Only if it doesn't exist or we want to update it)
    # We use sudo tee because /usr/local/bin requires root permissions
    if [ ! -f "$BIN_PATH" ] || grep -q "MC_REGISTRY" "$BIN_PATH"; then
        cat << 'EOF' | sudo tee "$BIN_PATH" > /dev/null
#!/bin/bash
REGISTRY="$HOME/.mc_registry"

# --- HELPER: LIST SERVERS ---
list_servers() {
    echo "Registered Servers:"
    echo "-------------------"
    if [ ! -s "$REGISTRY" ]; then
        echo "No servers found."
        return
    fi
    # Read file, print formatted columns (Name -> Path)
    column -t -s '|' "$REGISTRY" | sed 's/^/  - /'
    echo "-------------------"
}

# --- MODE 1: LIST ---
if [ "$1" == "list" ]; then
    list_servers
    exit 0
fi

# --- MODE 2: SPECIFIC SERVER ---
TARGET_NAME="$1"

# If no argument provided, show interactive menu
if [ -z "$TARGET_NAME" ]; then
    echo "Select a server to manage:"
    # Read registry into array
    mapfile -t SERVERS < <(cut -d'|' -f1 "$REGISTRY")

    if [ ${#SERVERS[@]} -eq 0 ]; then
        echo "No servers registered."
        exit 1
    fi

    select s in "${SERVERS[@]}"; do
        if [ -n "$s" ]; then
            TARGET_NAME="$s"
            break
        else
            echo "Invalid selection."
        fi
    done
fi

# Find the path for the selected server
TARGET_PATH=$(grep "^$TARGET_NAME|" "$REGISTRY" | cut -d'|' -f2 | head -n 1)

if [ -z "$TARGET_PATH" ]; then
    echo "Error: Server '$TARGET_NAME' not found in registry."
    list_servers
    exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
    echo "Error: Directory '$TARGET_PATH' no longer exists."
    exit 1
fi

# Launch Dashboard
cd "$TARGET_PATH" || exit
if [ -f "./dashboard.sh" ]; then
    ./dashboard.sh
else
    echo "Error: dashboard.sh not found in $TARGET_PATH"
fi
EOF
        # Make it executable
        sudo chmod +x "$BIN_PATH"
        echo "✅ Global command 'mcserver' installed/updated."
    fi

    echo "✅ Server '$NAME' registered successfully."
}

install_dashboard(){
cat << 'EOF' > dashboard.sh
#!/bin/bash

# ==============================================================================
# 🎛️ MINECRAFT SERVER DASHBOARD (Centered & Responsive)
# ==============================================================================

# --- CONFIGURATION ---
SERVER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# --- TPUT STYLING ---
BOLD=$(tput bold); NORM=$(tput sgr0)
RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4); CYAN=$(tput setaf 6); WHITE=$(tput setaf 7); GRAY=$(tput setaf 8)

# --- UI CONSTANTS ---
# We need to know the exact width/height of our "box" to center it.
# Based on the longest line in draw_ui + padding
UI_WIDTH=55
UI_HEIGHT=18

# --- AUTO-DETECT SCREEN ---
detect_screen() {
    DETECTED_SCREEN=$(screen -ls | grep -E "minecraft|mcserver|Forge|Paper" | awk '{print $1}' | cut -d. -f2 | head -n 1)
    if [ -z "$DETECTED_SCREEN" ]; then
        DETECTED_SCREEN=$(screen -ls | grep -P '^\t\d+\.' | awk '{print $1}' | cut -d. -f2 | head -n 1)
    fi
    SCREEN_NAME="${DETECTED_SCREEN:-minecraft}"
}

# --- PROCESS FINDER ---
find_java_pid() {
    JAVA_PID=""
    for pid in $(pgrep -u "$(whoami)" java); do
        PROCESS_DIR=$(readlink -f /proc/$pid/cwd)
        if [[ "$PROCESS_DIR" == "$SERVER_DIR" ]]; then
            JAVA_PID=$pid
            break
        fi
    done
}

# --- AUTO-START LOGIC ---
check_autostart() {
    # Check if this specific directory is in the crontab
    if crontab -l 2>/dev/null | grep -F "$SERVER_DIR" | grep -q "@reboot"; then
        AUTOSTART_MSG="${GREEN}${BOLD}ON${NORM}"
        AUTOSTART_STATE="on"
    else
        AUTOSTART_MSG="${RED}${BOLD}OFF${NORM}"
        AUTOSTART_STATE="off"
    fi
}

toggle_autostart() {
    # Define the command we want to add/remove
    # We use 'run.sh' if it exists (NeoForge), otherwise 'start.sh'
    if [ -f "$SERVER_DIR/run.sh" ]; then START_SCRIPT="run.sh"; else START_SCRIPT="start.sh"; fi

    CRON_CMD="@reboot /usr/bin/screen -dmS $SCREEN_NAME /bin/bash $SERVER_DIR/$START_SCRIPT"

    if [ "$AUTOSTART_STATE" == "on" ]; then
        # DISABLE: Remove the line containing our server path
        (crontab -l 2>/dev/null | grep -vF "$SERVER_DIR") | crontab -
        echo "✅ Auto-start disabled."
    else
        # ENABLE: Append the command
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo "✅ Auto-start enabled."
    fi
}

# --- STATS ENGINE ---
get_server_stats() {
    detect_screen
    if screen -list | grep -q "$SCREEN_NAME"; then
        STATUS="${GREEN}${BOLD}ONLINE${NORM}"
        find_java_pid

        if [ -n "$JAVA_PID" ]; then
            STATS=$(ps -p $JAVA_PID -o %cpu=,rss=)
            CPU_RAW=$(echo "$STATS" | awk '{print $1}')
            RAM_KB=$(echo "$STATS" | awk '{print $2}')
            RAM_MB=$((RAM_KB / 1024))

            # RAM Bar (Assume 12GB scale)
            MAX_RAM_VISUAL=12288
            RAM_PERCENT=$(( (RAM_MB * 100) / MAX_RAM_VISUAL ))
            [[ $RAM_PERCENT -gt 100 ]] && RAM_PERCENT=100
            draw_bar $RAM_PERCENT
            RAM_BAR=$BAR_OUTPUT

            # CPU Bar
            CPU_INT=${CPU_RAW%.*}
            [[ $CPU_INT -gt 100 ]] && CPU_VISUAL=100 || CPU_VISUAL=$CPU_INT
            draw_bar $CPU_VISUAL
            CPU_BAR=$BAR_OUTPUT

            STATS_TEXT_1="${WHITE}RAM:${NORM} [${CYAN}${RAM_BAR}${NORM}] ${WHITE}${RAM_MB}MB${NORM}"
            STATS_TEXT_2="${WHITE}CPU:${NORM} [${GREEN}${CPU_BAR}${NORM}] ${WHITE}${CPU_RAW}%${NORM}"
            PID_TEXT="${GRAY}(PID: $JAVA_PID)${NORM}"
        else
            STATUS="${YELLOW}${BOLD}STARTING${NORM}"
            STATS_TEXT_1="${YELLOW}Waiting for Java...${NORM}"
            STATS_TEXT_2=""
            PID_TEXT=""
        fi
    else
        STATUS="${RED}${BOLD}OFFLINE${NORM}"
        STATS_TEXT_1="${GRAY}Server is stopped.${NORM}"
        STATS_TEXT_2=""
        PID_TEXT=""
    fi
}

draw_bar() {
    local PERCENT=$1; local SIZE=20
    local FILLED=$(( (PERCENT * SIZE) / 100 ))
    local EMPTY=$(( SIZE - FILLED ))
    BAR_OUTPUT=""
    for ((i=0; i<FILLED; i++)); do BAR_OUTPUT="${BAR_OUTPUT}#"; done
    for ((i=0; i<EMPTY; i++)); do BAR_OUTPUT="${BAR_OUTPUT}."; done
}

# --- DRAWING ENGINE (Centered) ---
draw_ui() {
    get_server_stats

    # Calculate Center Coordinates
    TERM_COLS=$(tput cols)
    TERM_LINES=$(tput lines)

    # Math: (TermWidth - BoxWidth) / 2
    PAD_LEFT=$(( (TERM_COLS - UI_WIDTH) / 2 ))
    PAD_TOP=$(( (TERM_LINES - UI_HEIGHT) / 2 ))

    # Ensure we don't go negative if terminal is too small
    [[ $PAD_LEFT -lt 0 ]] && PAD_LEFT=0
    [[ $PAD_TOP -lt 0 ]] && PAD_TOP=0

    # Helper function to print a line at specific offset
    # Usage: print_line "RowIndex" "Content"
    print_line() {
        local ROW=$1
        local CONTENT=$2
        tput cup $((PAD_TOP + ROW)) $PAD_LEFT
        echo -e "$CONTENT"
    }

    # Draw the Box
    print_line 0  "${BLUE}=======================================================${NORM}"
    print_line 1  "       👾  ${BOLD}MINECRAFT SERVER DASHBOARD${NORM}  👾"
    print_line 2  "${BLUE}=======================================================${NORM}"
    print_line 3  " Path:      ${GRAY}${SERVER_DIR}${NORM}"
    print_line 4  " Session:   ${CYAN}${SCREEN_NAME}${NORM} $PID_TEXT"
    print_line 5  " Status:    $STATUS"
    print_line 6  ""
    print_line 7  " $STATS_TEXT_1"
    print_line 8  " $STATS_TEXT_2"
    print_line 9  ""
    print_line 10 "${BLUE}-------------------------------------------------------${NORM}"
    print_line 11 "   ${GREEN}[1]${NORM} ▶ Start Server      ${YELLOW}[4]${NORM} 💾 Force Backup"
    print_line 12 "   ${RED}[2]${NORM} ■ Stop Server       ${YELLOW}[5]${NORM} 📦 Install Modpack"
    print_line 13 "   ${CYAN}[3]${NORM} > Open Console      ${YELLOW}[6]${NORM} 🌐 Playit.gg Status"
    print_line 14 "   ${RED}[Q]${NORM} Quit"
    print_line 15 "${BLUE}=======================================================${NORM}"
    print_line 16 " ${WHITE}Live Monitoring...${NORM}                             "

    # Move cursor out of the way (bottom right)
    tput cup $TERM_LINES $TERM_COLS
}

# --- INIT ---
tput civis; trap "tput cnorm; clear; exit" EXIT; clear

# --- MAIN LOOP ---
while true; do
    draw_ui
    read -t 1 -n 1 -s key
    if [ -n "$key" ]; then
        case $key in
            1)
                clear; echo -e "\n${GREEN}--> Starting Server...${NORM}"
                if [ -f "./start.sh" ]; then ./start.sh; elif [ -f "./run.sh" ]; then ./run.sh; else echo "No start script found!"; fi
                read -p "Press Enter..."; clear ;;
            2)
                clear; echo -e "\n${RED}--> Stopping Server...${NORM}"
                ./stop.sh
		read -p "Press Enter..."; clear ;;
            3)
                tput cnorm; clear; echo -e "${CYAN}--> Opening Console... (Ctrl+A, D to exit)${NORM}"; sleep 1
                screen -r "$SCREEN_NAME"; tput civis; clear ;;
            4)
                clear; echo -e "\n${YELLOW}--> Backup...${NORM}"; [ -f "./backup.sh" ] && ./backup.sh; read -p "Done."; clear ;;
            5)
                tput cnorm; clear; [ -f "./install_modpack.sh" ] && ./install_modpack.sh; read -p "Done."; tput civis; clear ;;
            6)
                clear; echo -e "\n${CYAN}--> Playit.gg${NORM}"; sudo systemctl status playit --no-pager; read -p "Done."; clear ;;
            q|Q) exit 0 ;;
            7)
                clear; echo -e "\n${MAGENTA}--> Toggling Auto-Start...${NORM}"
                toggle_autostart; read -p "Press Enter..."; clear ;;
            q|Q) exit 0 ;;
        esac
    fi
done

}
install_playit() {
    echo -e "--> Installing Playit.gg..."

    # 1. Download Binary
    curl -L -s https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64 -o playit
    chmod +x playit
    sudo mv playit /usr/local/bin/playit

    # 2. Create Systemd Service (Auto-Start)
    echo -e "--> Creating System Service..."
    cat << 'EOF' | sudo tee /etc/systemd/system/playit.service > /dev/null
[Unit]
Description=Playit.gg Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/playit
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 3. Enable Service
    sudo systemctl daemon-reload
    sudo systemctl enable playit

    echo "✅ Playit.gg installed!"
    echo "----------------------------------------------------"
    echo "⚠️  ACTION REQUIRED: Run 'playit' manually once to claim this server!"
    echo "   (After claiming, press Ctrl+C and run 'sudo systemctl start playit')"
    echo "----------------------------------------------------"
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
cat << EOF > stop.sh
#!/bin/bash
SCREEN_NAME="$SCREEN_NAME"
JAR_FILE="$JAR_FILE"
if ! screen -list | grep -q "\$SCREEN_NAME"; then
    echo "⚠️  Server is not running."
    exit 1
fi
echo "🛑 Sending 'stop' command..."
screen -S \$SCREEN_NAME -X stuff "stop^M"
echo "⏳ Waiting for server to save and close..."
while screen -list | grep -q "\$SCREEN_NAME"; do
    if ! pgrep -f "\$JAR_FILE" > /dev/null; then
        echo "Server process finished. Closing screen session..."
        screen -S \$SCREEN_NAME -X quit
        break
    fi
    sleep 1
done
echo "✅ Server stopped."
EOF
chmod +x stop.sh
echo "✅ Created stop.sh"
}

create_start_script() {
    # Logic to handle different start commands
    if [ "$SERVER_TYPE" == "2" ]; then
        # NeoForge uses run.sh
        START_CMD="./run.sh"
    else
        # Paper uses java -jar
        START_CMD="java -Xms$RAM -Xmx$RAM -jar $JAR_FILE nogui"
    fi

cat << EOF > start.sh
#!/bin/bash
SCREEN_NAME="$SCREEN_NAME"

if [ -z "\$STY" ]; then
    if screen -list | grep -q "\$SCREEN_NAME"; then
        echo "⚠️  Server is already running! Type 'screen -r \$SCREEN_NAME' to view it."
    else
        echo "🚀 Starting Minecraft server in background screen '\$SCREEN_NAME'..."
        screen -dmS \$SCREEN_NAME "\$0"
        echo "✅ Done! Server is booting up."
        echo "   - View console: screen -r \$SCREEN_NAME"
        echo "   - Detach again: Ctrl + A, then D"
    fi
    exit
fi

while true
do
    echo "--- Starting Server ---"
    $START_CMD
    echo "---------------------------------------"
    echo "Server closed. Restarting in 5 seconds..."
    echo "Press CTRL+C NOW to stop the loop!"
    echo "---------------------------------------"
    sleep 5
done
EOF
chmod +x start.sh
echo "✅ Created start.sh"
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
cat << EOF > forcekill.sh
#!/bin/bash
SCREEN_NAME="$SCREEN_NAME"
JAR_FILE="$JAR_FILE"

echo "☠️  EMERGENCY FORCE KILL INITIATED"
read -p "Type 'kill' to confirm: " CONFIRM
if [ "\$CONFIRM" != "kill" ]; then
    echo "❌ Aborted."
    exit 1
fi
screen -S \$SCREEN_NAME -X quit 2>/dev/null
pkill -9 -f "\$JAR_FILE"
echo "✅ Server terminated."
EOF
chmod +x forcekill.sh
echo "✅ Created forcekill.sh"
}

create_uninstall_script() {
cat << EOF > uninstall.sh
#!/bin/bash
CURRENT_DIR="\$(pwd)"
echo "⚠️  WARNING: PERMANENTLY DELETE SERVER?"
read -p "Type 'delete' to confirm: " CONFIRM
if [ "\$CONFIRM" != "delete" ]; then
    echo "❌ Cancelled."
    exit 1
fi
./forcekill.sh 2>/dev/null
crontab -l | grep -v "\$(pwd)" | crontab -
cd ..
rm -rf "\$(pwd)"
echo "✅ Uninstall Complete."
EOF
chmod +x uninstall.sh
echo "✅ Created uninstall.sh"
}
# ==========================================
# 🔧 Function: Generate Modpack Installer
# ==========================================
create_modpack_installer() {
    local TARGET_DIR="$1"

    # If no directory is passed, default to current
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="."
    fi

    echo -e "--> Creating 'install_modpack.sh' in ${TARGET_DIR}..."

# Create the file using a heredoc
cat << 'EOF' > "${TARGET_DIR}/install_modpack.sh"
#!/bin/bash
# --- Auto-Generated CurseForge Installer ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== CurseForge/NeoForge Pack Installer ===${NC}"

./forcekill.sh

# 1. Get Link
if [ -z "$1" ]; then
    echo -e "Paste the ${GREEN}download link${NC} for the Server Pack (zip):"
    read -r DOWNLOAD_URL
else
    DOWNLOAD_URL=$1
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "No URL provided."
    exit 1
fi

# 2. Download & Unzip
echo "--> Downloading..."
wget -O server_pack.zip "$DOWNLOAD_URL" || { echo "Download failed"; exit 1; }

echo "--> Extracting..."
if ! command -v unzip &> /dev/null; then
    echo "Installing unzip..."
    sudo apt-get install unzip -y
fi
unzip -o server_pack.zip
rm server_pack.zip

# 3. Flatten Nested Folders (Common in CurseForge packs)
DIR_COUNT=$(ls -d */ 2>/dev/null | wc -l)
FILE_COUNT=$(ls -p | grep -v / | wc -l)

# If only 1 folder exists and almost no files, move contents out
if [ "$DIR_COUNT" -eq 1 ] && [ "$FILE_COUNT" -le 2 ]; then
    SUBFOLDER=$(ls -d */)install_playit() {
    echo -e "--> Installing Playit.gg..."

    # 1. Download Binary
    curl -L -s https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64 -o playit
    chmod +x playit
    sudo mv playit /usr/local/bin/playit

    # 2. Create Systemd Service (Auto-Start)
    echo -e "--> Creating System Service..."
    cat << 'EOF' | sudo tee /etc/systemd/system/playit.service > /dev/null
[Unit]
Description=Playit.gg Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/playit
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 3. Enable Service
    sudo systemctl daemon-reload
    sudo systemctl enable playit

    echo "✅ Playit.gg installed!"
    echo "----------------------------------------------------"
    echo "⚠️  ACTION REQUIRED: Run 'playit' manually once to claim this server!"
    echo "   (After claiming, press Ctrl+C and run 'sudo systemctl start playit')"
    echo "----------------------------------------------------"
}
    SUBFOLDER=${SUBFOLDER%/} # remove trailing slash
    echo "--> Moving files out of subfolder: $SUBFOLDER"
    mv "$SUBFOLDER"/* . 2>/dev/null
    mv "$SUBFOLDER"/.* . 2>/dev/null
    rmdir "$SUBFOLDER"
fi

# 4. NeoForge/Forge Specifics
echo "--> Setting permissions..."
chmod +x *.sh 2>/dev/null
chmod +x user_jvm_args.txt 2>/dev/null

# Auto-accept EULA
echo "eula=true" > eula.txt

# Check for NeoForge installer jar if no script exists yet
if [ ! -f "run.sh" ] && [ ! -f "start.sh" ]; then
    INSTALLER_JAR=$(ls *installer.jar 2>/dev/null | head -n 1)
    if [ -n "$INSTALLER_JAR" ]; then
        echo -e "${GREEN}--> Found Installer Jar: $INSTALLER_JAR${NC}"
        echo "You may need to run: java -jar $INSTALLER_JAR --installServer"
    fi
fi

echo -e "${GREEN}Done! Run ./install_modpack.sh to repeat or ./run.sh to start.${NC}"
EOF

    # Make the generated script executable
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
    if [[ "$EULA_CHOICE" =~ ^[Yy]$ ]]; then
        install_playit
    fi
    # Auto-EULA
    read -p "Auto-accept EULA? (y/n): " EULA_CHOICE
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
    setup_global_command
}

# ==========================================
# 2. MAIN EXECUTION
# ==========================================

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
echo "👉 Use ./start.sh to launch your server."

# ==========================================
# Self-Cleanup
# ==========================================
echo "🧹 Cleaning up installer file..."
rm -- "$SCRIPT_PATH"
