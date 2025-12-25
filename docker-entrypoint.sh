#!/bin/bash

echo "🐳 Container Starting..."

# 1. First Run Setup
if [ ! -f "./start.sh" ]; then
    echo "📂 New setup detected. Running installer..."
    # Run your installer in "Docker Mode"
    # We pass the environment variables directly
    /opt/install.sh --docker --refresh

    # Auto-accept EULA if set in ENV
    if [ "$EULA" == "true" ]; then
        echo "eula=true" > eula.txt
    fi
fi

# 2. Start Cron (For your backups)
service cron start

# 3. Graceful Shutdown Handler
# When Docker sends a stop signal, we run your stop.sh
term_handler() {
    echo "🛑 Docker Stop Signal Received!"
    if [ -f "./stop.sh" ]; then
        ./stop.sh
    else
        screen -S minecraft -X quit
    fi
    exit 0
}

# Trap the signals
trap 'term_handler' SIGTERM SIGINT

# 4. Start the Server (Background Screen)
# We use your generated start.sh
echo "🚀 Starting Minecraft via Screen..."
screen -dmS minecraft ./start.sh

# 5. Keep Container Alive & Monitor
# We loop here so the container doesn't exit.
# We also check if the screen session is still alive.
echo "✅ Server is up. Use 'docker exec -it mc-server ./dashboard.sh' to manage."

while true; do
    # check if screen is running
    if ! screen -list | grep -q "minecraft"; then
        echo "⚠️ Screen session died! Container exiting."
        exit 1
    fi
    sleep 5 &
    wait $!
done
