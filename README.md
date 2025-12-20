**Personal script for installing a minecraft server on a debian based system**

# Minecraft Server Manager

A lightweight, automated script suite for deploying and managing a PaperMC server on any Debian/Ubuntu system (including Raspberry Pi).

## Features
* **One-Command Install:** Sets up Java 21, Screen, and dependencies automatically.
* **Auto-Updater:** Fetches the absolute latest PaperMC build via API.
* **Smart Backups:** Auto-runs every 4 hours. Pauses server saving to prevent corruption, zips files, and auto-deletes backups older than 7 days.
* **Resilience:** Auto-starts on server boot/reboot.
* **Easy Management:**
    * `./start.sh` - Starts server in a background screen (no terminal hostage).
    * `./stop.sh` - Gracefully stops server and kills the screen loop.
    * `./forcekill.sh` - "Kill-switch" (Forcekills the server without saving)
    * `./restart.sh` - Full safe reboot cycle.
    * `./uninstall.sh` - "Self-destruct" (Stops server, removes cron jobs, deletes files).

## Quick Install
Run this single command on your server to install everything:

```bash
git clone https://github.com/Flanz1/mc-server-scripts.git minecraft-server && cd minecraft-server && chmod +x install.sh && ./install.sh
