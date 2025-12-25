#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")

# Settings
REPO_BASE="https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main"
DEFAULT_DIR="mc-docker"

echo "🐳 --- Minecraft Docker Auto-Installer ---"

# 1. Directory Selection
if [ -n "$1" ]; then
    INPUT_DIR="$1"
else
    read -p "Enter desired directory for docker deployment [Default: $DEFAULT_DIR]: " INPUT_DIR
fi

TARGET_DIR="${INPUT_DIR:-$DEFAULT_DIR}"
TARGET_DIR=$(eval echo "$TARGET_DIR") # Fix tilde ~

echo "-> Target Directory: $TARGET_DIR"

if [ -z "$TARGET_DIR" ] || [ "$TARGET_DIR" == "/" ]; then
    echo "❌ Error: Invalid directory selected."
    exit 1
fi

# 2. Create Folder
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "❌ Failed to enter directory"; exit 1; }

# 3. Download Files
echo "⬇️  Downloading configuration files..."
wget -q -O install.sh "$REPO_BASE/install.sh"
wget -q -O Dockerfile "$REPO_BASE/dockerfile"
wget -q -O docker-compose.yml "$REPO_BASE/docker-compose.yml"
wget -q -O docker-entrypoint.sh "$REPO_BASE/docker-entrypoint.sh"

# 4. Permissions
chmod +x install.sh docker-entrypoint.sh

# ==========================================
# 🧠 SMART CONFIGURATION WIZARD
# ==========================================
echo "------------------------------------------------"
echo "Select Server Type:"
echo "1) PaperMC (Plugins)"
echo "2) NeoForge (Mods)"
read -p "Selection [1]: " TYPE_INPUT
SERVER_TYPE="${TYPE_INPUT:-1}"

# Update Type in docker-compose.yml
sed -i "s/SERVER_TYPE=[0-9]*/SERVER_TYPE=$SERVER_TYPE/" docker-compose.yml

# --- NEOFORGE VALIDATION LOGIC ---
if [ "$SERVER_TYPE" == "2" ]; then
    while true; do
        echo ""
        read -p "Enter NeoForge Version (e.g., 21.1.73): " NF_VERSION

        if [ -z "$NF_VERSION" ]; then echo "❌ Version cannot be empty."; continue; fi

        # Construct the exact URL NeoForge uses
        CHECK_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/${NF_VERSION}/neoforge-${NF_VERSION}-installer.jar"

        echo "🔍 Verifying version $NF_VERSION on NeoForge Maven..."

        # Use curl --head to check if file exists (HTTP 200) without downloading it
        if curl --output /dev/null --silent --head --fail "$CHECK_URL"; then
            echo "✅ Version found!"

            # Inject the version into docker-compose.yml
            # We add a new line to the environment variables block
            sed -i "/environment:/a \      - NEOFORGE_VERSION=$NF_VERSION" docker-compose.yml
            break
        else
            echo "❌ Error: Version '$NF_VERSION' does not exist on NeoForge servers."
            echo "   Please check the number and try again."
        fi
    done
fi
echo "------------------------------------------------"

# 5. Launch
echo "🚀 Building and Starting Container..."

if sudo docker compose up -d --build; then
    echo "✅ Successfully started with Docker Compose (v2)"
elif sudo docker-compose up -d --build; then
    echo "✅ Successfully started with Docker Compose (v1)"
else
    echo "❌ Error: Docker Compose failed to start."
    exit 1
fi

echo ""
echo "✅ Server started!"
echo "👉 Manage it with: sudo docker exec -it mc-server ./dashboard.sh"

# 6. Cleanup Self
if [ -f "$SCRIPT_PATH" ]; then
    rm -- "$SCRIPT_PATH"
fi
