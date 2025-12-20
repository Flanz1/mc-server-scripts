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
crontab -l | grep -v "\$CURRENT_DIR" | crontab -
cd ..
rm -rf "\$CURRENT_DIR"
echo "✅ Uninstall Complete."
EOF
chmod +x uninstall.sh
echo "✅ Created uninstall.sh"
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
    echo "⚠️  Installing in CURRENT directory: $(pwd)"
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
