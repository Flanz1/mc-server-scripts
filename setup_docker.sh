#!/bin/bash
SCRIPT_PATH=$(readlink -f "$0")

# Settings
REPO_BASE="https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main"
DEFAULT_DIR="mc-docker"

echo "🐳 --- Minecraft Docker Auto-Installer ---"

# 1. Directory Selection Logic
if [ -n "$1" ]; then
    TARGET_DIR="$1"
else
    read -p "Enter desired directory for docker deployment [Default: $DEFAULT_DIR]: " INPUT_DIR
    TARGET_DIR="${INPUT_DIR:-$DEFAULT_DIR}"
fi

echo "-> Target Directory: $TARGET_DIR"

# 2. Create Folder
if [ -d "$TARGET_DIR" ]; then
    echo "⚠️  Directory '$TARGET_DIR' already exists. Using it."
else
    echo "📂 Creating directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

cd "$TARGET_DIR" || { echo "❌ Failed to enter directory"; exit 1; }

# 3. Download Files
echo "⬇️  Downloading configuration files..."
wget -q -O install.sh "$REPO_BASE/install.sh"
wget -q -O Dockerfile "$REPO_BASE/Dockerfile"
wget -q -O docker-compose.yml "$REPO_BASE/docker-compose.yml"
wget -q -O docker-entrypoint.sh "$REPO_BASE/docker-entrypoint.sh"

# 4. Permissions
chmod +x install.sh docker-entrypoint.sh

# 5. Launch
echo "🚀 Building and Starting Container..."
if command -v docker-compose &> /dev/null; then
    sudo docker-compose up -d --build
else
    sudo docker compose up -d --build
fi

echo ""
echo "✅ Server started!"
echo "👉 Manage it with: sudo docker exec -it mc-server ./dashboard.sh"

# 6. Cleanup Self
echo "🧹 Cleaning up installer file..."
if [ -f "$SCRIPT_PATH" ]; then
    rm -- "$SCRIPT_PATH"
fi
