# 🛠️ Universal Minecraft Server Manager

A powerful, all-in-one shell script to install, manage, and protect your Minecraft server (PaperMC or NeoForge). It comes with a TUI Dashboard, auto-backups, crash detection, and smart update tools.

## ✨ Key Features

* **🚀 Universal Installer:** Sets up **PaperMC** or **NeoForge** (Modpacks) with Java 21 automatically.
* **🎮 TUI Dashboard:** A visual menu to control everything without memorizing commands.
* **💾 Smart Backups:** Automated backups every 4 hours (excludes heavy logs/backups to save space).
* **⏪ Interactive Restore:** Rollback your server to a previous state with a simple menu.
* **🔄 Safe Updates:** Wraps the update process in a "Backup -> Stop -> Update -> Restart" safety loop.
* **🛡️ Crash Detection:** Automatically restarts the server if it crashes or stops unexpectedly.
* **🌐 Playit.gg Support:** Built-in installer for easy port forwarding.

## 📥 Installation

Run this one-liner on your Linux machine (Ubuntu/Debian recommended):

```bash
    wget -qO install.sh https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main/install.sh && chmod +x install.sh && ./install.sh

```

Follow the on-screen prompts to select your server type (Paper/NeoForge), set RAM, and choose a folder name.

## 🖥️ How to Use

### 1. The Global Command

Once installed, you don't need to remember where you put the server. Just type:

```bash
mcserver list           # List all installed servers
mcserver <folder_name>  # Open the Dashboard for that server
mcserver # Open a selection screen for all installed servers

```

### 2. The Dashboard Menu

When you open the dashboard, you can use these keys:

* `[1]` **Start:** Launches the server in a background screen.
* `[2]` **Stop:** Gracefully stops the server (waits for saves).
* `[3]` **Console:** View the live server logs (Ctrl+A, D to detach).
* `[4]` **Force Backup:** Trigger a manual backup immediately.
* `[6]` **Update:** Safely updates server JAR/Modpack.
* `[R]` **Restore:** Pick a previous backup to restore from.
* `[M]` **Modpack:** Install a new modpack zip from a link.

## 📂 File Structure

Your server folder will contain these helpful scripts:

| File | Description |
| --- | --- |
| `dashboard.sh` | The main menu interface. |
| `start.sh` | Starts the server with an infinite restart loop (Crash protection). |
| `stop.sh` | safely stops the server (runs backup first, then `stop` command). |
| `restart.sh` | Runs stop.sh, waits, then runs start.sh. |
| `backup.sh` | Compresses the world/files (ignores logs) to `./backups`. |
| `restore.sh` | Interactive menu to unzip a backup and overwrite current files. |
| `server_update.sh` | The "Safe Wrapper" that backs up before updating. |
| `forcekill.sh` | Emergency script. Kills the specific Java PID for this folder. |

## ⚙️ Automation

* **Auto-Start:** The script creates a systemd service so your server boots up when the VPS/PC turns on.
* **Auto-Backup:** A cron job runs every **4 hours** to keep your world safe.
* **Auto-Restart:** Configurable daily restart via the Dashboard (Option `[9]`).
