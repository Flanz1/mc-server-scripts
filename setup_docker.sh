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

# Fallback to default if input is empty
TARGET_DIR="${INPUT_DIR:-$DEFAULT_DIR}"

# --- FIX: Tilde Expansion (The Safe Way) ---
# We use eval echo to force the shell to expand ~ to /home/user
# This turns "~/docker/mcserver" into "/home/marko/docker/mcserver"
TARGET_DIR=$(eval echo "$TARGET_DIR")

echo "-> Target Directory: $TARGET_DIR"

# Safety Check: Ensure directory isn't empty or root
if [ -z "$TARGET_DIR" ] || [ "$TARGET_DIR" == "/" ]; then
    echo "❌ Error: Invalid directory selected."
    exit 1
fi

# 2. Create Folder
if [ -d "$TARGET_DIR" ]; then
    echo "⚠️  Directory exists. Using it."
else
    echo "📂 Creating directory..."
    mkdir -p "$TARGET_DIR"
fi

cd "$TARGET_DIR" || { echo "❌ Failed to enter directory"; exit 1; }

# 3. Download Files
echo "⬇️  Downloading configuration files..."
wget -q -O install.sh "$REPO_BASE/install.sh"
wget -q -O Dockerfile "$REPO_BASE/dockerfile"
wget -q -O docker-compose.yml "$REPO_BASE/docker-compose.yml"
wget -q -O docker-entrypoint.sh "$REPO_BASE/docker-entrypoint.sh"

# 4. Permissions
chmod +x install.sh docker-entrypoint.sh

# 5. Launch
echo "🚀 Building and Starting Container..."
# Check for modern 'docker compose' (v2) first, then legacy 'docker-compose' (v1)
if docker compose version &> /dev/null; then
    sudo docker compose up -d --build
elif command -v docker-compose &> /dev/null; then
    sudo docker-compose up -d --build
else
    echo "❌ Error: Docker Compose not found!"
    exit 1
fi

echo ""
echo "✅ Server started!"
echo "👉 Manage it with: sudo docker exec -it mc-server ./dashboard.sh"

# 6. Cleanup Self
if [ -f "$SCRIPT_PATH" ]; then
    rm -- "$SCRIPT_PATH"
fi
