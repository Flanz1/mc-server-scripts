#!/bin/bash

# ==========================================
# 📦 CurseForge Modpack Installer
# ==========================================

# Colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== CurseForge Server Pack Installer ===${NC}"

# 1. Get the Download Link
# You can pass the link as an argument or paste it when asked
if [ -z "$1" ]; then
    echo -e "Paste the ${H_YELLOW}download link${NC} for the CurseForge Server Pack (zip):"
    read -r DOWNLOAD_URL
else
    DOWNLOAD_URL=$1
fi

# Validate input
if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Error: No URL provided. Exiting.${NC}"
    exit 1
fi

# 2. Preparation
echo -e "${CYAN}--> Preparing directory...${NC}"
# Check if unzip is installed
if ! command -v unzip &> /dev/null; then
    echo "unzip could not be found, installing..."
    sudo apt-get install unzip -y
fi

# 3. Download the Pack
echo -e "${CYAN}--> Downloading Server Pack...${NC}"
wget -O server_pack.zip "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
    echo -e "${RED}Download failed. Check the link and try again.${NC}"
    exit 1
fi

# 4. Extract Files
echo -e "${CYAN}--> Extracting files...${NC}"
unzip -o server_pack.zip
rm server_pack.zip

# 5. Fix Permissions & Organization
echo -e "${CYAN}--> Setting permissions and organizing...${NC}"

# Often packs unzip into a subfolder. Move them out if needed.
# This finds if there is only one folder inside and moves content out.
DIR_COUNT=$(ls -1 | wc -l)
if [ "$DIR_COUNT" -eq 1 ]; then
    SUBFOLDER=$(ls -1)
    if [ -d "$SUBFOLDER" ]; then
        echo "Detected nested folder '$SUBFOLDER'. Moving files to root..."
        mv "$SUBFOLDER"/* .
        rmdir "$SUBFOLDER"
    fi
fi

# Make scripts executable
chmod +x *.sh 2>/dev/null
chmod +x user_jvm_args.txt 2>/dev/null # Sometimes needed for newer Forge

# 6. Auto-Accept EULA
echo -e "${CYAN}--> Accepting EULA...${NC}"
if [ -f "eula.txt" ]; then
    sed -i 's/eula=false/eula=true/g' eula.txt
else
    echo "eula=true" > eula.txt
fi

# 7. Check for Installer Scripts
# Some modern packs need you to run a specific installer first
if [ -f "run.sh" ]; then
    MAIN_SCRIPT="./run.sh"
elif [ -f "start.sh" ]; then
    MAIN_SCRIPT="./start.sh"
elif [ -f "Install.sh" ]; then
    echo -e "${GREEN}Found an 'Install.sh'. You might need to run that once manually.${NC}"
    MAIN_SCRIPT="./Install.sh"
elif [ -f "ServerStart.sh" ]; then
    MAIN_SCRIPT="./ServerStart.sh"
fi

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "You can likely start the server with: ${CYAN}$MAIN_SCRIPT${NC}"
echo -e "Don't forget to check 'server.properties' for port settings."
echo -e "${GREEN}==========================================${NC}"
