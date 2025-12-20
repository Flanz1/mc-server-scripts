#!/bin/bash

# ==========================================
# Minecraft Server Script Installer
# ==========================================

echo "🛠️  Setting up your Minecraft Server Manager..."
echo ""

# 1. Gather Configuration
read -p "Enter RAM amount (e.g., 4G): " RAM_INPUT
read -p "Enter Server JAR name (e.g., server.jar): " JAR_INPUT
SCREEN_NAME="minecraft"

# Default values if user hits enter
RAM=${RAM_INPUT:-4G}
JAR_FILE=${JAR_INPUT:-server.jar}

echo ""
echo "📝 Configuration saved:"
echo "   - RAM: $RAM"
echo "   - JAR: $JAR_FILE"
echo "   - Screen Name: $SCREEN_NAME"
echo ""

# ==========================================
# 2. Create start.sh (Self-Screening + Loop)
# ==========================================
cat << EOF > start.sh
#!/bin/bash

# Configuration
SCREEN_NAME="$SCREEN_NAME"
RAM="$RAM"
JAR_FILE="$JAR_FILE"

# PHASE 1: The "Launcher" (Checks if we are in screen)
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

# PHASE 2: The "Loop" (Runs inside screen)
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
# 3. Create stop.sh (Smart Safer)
# ==========================================
cat << EOF > stop.sh
#!/bin/bash

SCREEN_NAME="$SCREEN_NAME"

# Check if running
if ! screen -list | grep -q "\$SCREEN_NAME"; then
    echo "⚠️  Server is not running."
    exit 1
fi

echo "🛑 Sending 'stop' command..."
screen -S \$SCREEN_NAME -X stuff "stop^M"

echo "⏳ Waiting for server to save and close..."
while screen -list | grep -q "\$SCREEN_NAME"; do
    # If Java is gone, force kill the screen to stop the loop
    if ! pgrep -f "$JAR_FILE" > /dev/null; then
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
# 4. Create restart.sh (Full Cycle)
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
# 5. Finish Up
# ==========================================
chmod +x start.sh stop.sh restart.sh
echo ""
echo "🎉 Installation Complete!"
echo "------------------------------------------------"
echo "1. Start server:   ./start.sh"
echo "2. Stop server:    ./stop.sh"
echo "3. Restart server: ./restart.sh"
echo "------------------------------------------------"
