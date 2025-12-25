#!/bin/bash

# Settings
REPO_BASE="https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main"
TARGET_DIR="${1:-mc-docker}" # Default folder name is 'mc-docker', or user can provide one

echo "🐳 --- Minecraft Docker Auto-Installer ---"
if [ -n "$1" ]; then
    TARGET_DIR="$1"
else
    read -p "Enter desired directory for docker deployment: " TARGET_DIR
fi

echo "-> Target Directory: $TARGET_DIR"

# 1. Create Folder
if [ -d "$TARGET_DIR" ]; then
    echo "⚠️  Directory '$TARGET_DIR' already exists. Using it."
else
    echo "📂 Creating directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

cd "$TARGET_DIR" || { echo "❌ Failed to enter directory"; exit 1; }

# 2. Download Files
echo "⬇️  Downloading configuration files..."
wget -q -O install.sh "$REPO_BASE/install.sh"
wget -q -O Dockerfile "$REPO_BASE/Dockerfile"
wget -q -O docker-compose.yml "$REPO_BASE/docker-compose.yml"
wget -q -O docker-entrypoint.sh "$REPO_BASE/docker-entrypoint.sh"

# 3. Permissions
chmod +x install.sh docker-entrypoint.sh

# 4. Launch
echo "🚀 Building and Starting Container..."
if command -v docker-compose &> /dev/null; then
    sudo docker-compose up -d --build
else
    sudo docker compose up -d --build
fi

echo ""
echo "✅ Server started!"
echo "👉 Manage it with: sudo docker exec -it mc-server ./dashboard.sh"
echo "🧹 Cleaning up installer file..."
# Cleanup self
if [ -f "$0" ]; then
    rm -- "$0"
fi
