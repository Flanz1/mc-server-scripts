#!/bin/bash

# ==========================================
# Universal Debian/Ubuntu Minecraft Installer
# ==========================================

echo "🛠️  Initializing Setup..."

# 1. Install System Dependencies AND Java 21
# We add 'openjdk-21-jre-headless' so the server can actually run on a fresh OS.
echo "📦 Installing system packages (Java 21, Screen, JQ, Curl)..."

sudo apt-get update -qq
# The '||' allows it to try default-jre if 21 isn't found (for older distros)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jre-headless screen jq curl || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre screen jq curl

echo "✅ System ready."
echo ""

# 2. Configuration
read -p "Enter RAM amount (e.g., 4G): " RAM_INPUT
RAM=${RAM_INPUT:-4G}
SCREEN_NAME="minecraft"
JAR_FILE="server.jar"

echo ""
echo "📝 Configuration saved:"
echo "   - RAM: $RAM"
echo "   - JAR: $JAR_FILE"
echo "   - Screen: $SCREEN_NAME"
echo ""

# ==========================================
# 3. Create update.sh (The PaperMC Fetcher)
# ==========================================
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
echo "✅ Created update.sh"

# ==========================================
# 4. Create start.sh (Self-Screening + Loop)
# ==========================================
cat << EOF > start.sh
#!/bin/bash
SCREEN_NAME="$SCREEN_NAME"
RAM="$RAM"
JAR_FILE="$JAR_FILE"

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
    java -Xms\$RAM -Xmx\$RAM -jar \$JAR_FILE nogui
    echo "---------------------------------------"
    echo "Server closed. Restarting in 5 seconds..."
    echo "Press CTRL+C NOW to stop the loop!"
    echo "---------------------------------------"
    sleep 5
done
EOF
echo "✅ Created start.sh"

# ==========================================
# 5. Create stop.sh (Smart Safer)
# ==========================================
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
echo "✅ Created stop.sh"

# ==========================================
# 6. Create restart.sh
# ==========================================
cat << EOF > restart.sh
#!/bin/bash
echo "🔄 Rebooting Server..."
./stop.sh
sleep 2
./start.sh
echo "✅ Server restarted successfully."
EOF
echo "✅ Created restart.sh"

# ==========================================
# 7b. Setup Scheduler (Auto-Start + Auto-Backup)
# ==========================================

CURRENT_DIR=$(pwd)

# Run backup every 4 hours
CRON_BACKUP="0 */4 * * * cd $CURRENT_DIR && ./backup.sh >> $CURRENT_DIR/backup.log 2>&1"
# Run start script immediately when the PC boots
CRON_START="@reboot cd $CURRENT_DIR && ./start.sh"

# We use 'grep -v' to remove old entries for this folder so we don't get duplicates if you run this twice.
(crontab -l 2>/dev/null | grep -v "$CURRENT_DIR"; echo "$CRON_BACKUP"; echo "$CRON_START") | crontab -

echo "✅ Auto-Backup scheduled (Every 4 hours)."
echo "✅ Auto-Start scheduled (Runs on Boot)."

# ==========================================
# 8. Create uninstall.sh
# ==========================================
cat << EOF > uninstall.sh
#!/bin/bash

CURRENT_DIR="\$(pwd)"

echo "⚠️  WARNING: This will PERMANENTLY DELETE this server and its backups!"
echo "   - Folder: \$CURRENT_DIR"
echo "   - Cron jobs: Auto-Start & Auto-Backups"
echo ""
read -p "Are you 100% sure? (Type 'delete' to confirm): " CONFIRM

if [ "\$CONFIRM" != "delete" ]; then
    echo "❌ Uninstall cancelled."
    exit 1
fi

echo "🛑 Stopping server if running..."
./stop.sh 2>/dev/null

echo "🧹 Removing Cron jobs (Auto-Start & Backups)..."
# This greps for the current directory path and removes those lines from crontab
crontab -l | grep -v "\$CURRENT_DIR" | crontab -

echo "🔥 Deleting server files..."
# We move out of the directory first so we can delete it
cd ..
rm -rf "\$CURRENT_DIR"

echo "✅ Uninstall Complete. The server is gone."
EOF
chmod +x uninstall.sh
echo "✅ Created uninstall.sh"

# ==========================================
# 9. Finalize
# ==========================================
chmod +x start.sh stop.sh restart.sh update.sh

echo ""
read -p "❓ Download latest PaperMC server file now? (y/n): " RUN_UPDATE
if [[ "$RUN_UPDATE" =~ ^[Yy]$ ]]; then
    ./update.sh
    read -p "❓ Would you like to initialize your minecraft server to generate config files? (y/n): " INIT_CONFIG
    if [[ "$INIT_CONFIG" =~ ^[Yy]$ ]]; then
    java -Xmx2G -jar server.jar nogui
    fi
fi

echo ""
echo "🎉 Installation Complete!"
