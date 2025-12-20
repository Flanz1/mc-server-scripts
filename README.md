# 🛠️ Universal Minecraft Server Installer

A robust, all-in-one Bash script to set up, manage, and maintain Minecraft servers on **Debian/Ubuntu** systems. Designed for performance and ease of use.

## ✨ Features

* **Multi-Platform Support:**
    * **PaperMC:** Automatically fetches the absolute latest build from the API.
    * **NeoForge:** Installs specific versions (perfect for modpacks like *All The Mods 10*).
* **Smart Automation:**
    * Installs dependencies (Java 21, Screen, JQ) automatically.
    * Handles "Headless" installation for NeoForge (no GUI needed).
    * **Auto-Cleaner:** Removes NeoForge clutter (`run.bat`, logs) and syncs RAM settings to `user_jvm_args.txt`.
* **Management Suite:** Generates custom helper scripts for easy management (`start`, `stop`, `update`, `uninstall`).

---

## 🚀 Quick Start

1.  **One command to download and install:**
   * ```Bash
      wget -qO install.sh https://raw.githubusercontent.com/Flanz1/mc-server-scripts/main/install.sh && chmod +x install.sh && ./install.sh
2.  **Follow the prompts:**
    * Choose Server Type: `1` for PaperMC, `2` for NeoForge.
    * Set RAM (e.g., `8G`).
    * Accept EULA.

---

## 🎮 Server Types

### 1. PaperMC (High Performance)
Best for vanilla-like survival, SMPs, and plugin support.
* **Updater:** The generated `update.sh` will automatically check the PaperMC API and upgrade you to the latest build of your version.

### 2. NeoForge (Modded / ATM10)
Best for heavy modpacks like *All The Mods 10*.
* **Installation:** Asks for the specific NeoForge version (e.g., `21.1.73`) to match your modpack.
* **RAM Management:** Automatically injects your RAM selection into `user_jvm_args.txt` so the server actually uses it.
* **Updater:** The `update.sh` allows you to switch NeoForge loader versions easily if the modpack updates.

---

## 🛠️ Management Commands

Once installed, use these scripts inside the folder to manage your server:

| Command | Description |
| :--- | :--- |
| `./start.sh` | Starts the server in a background `screen` session. |
| `./stop.sh` | Safely stops the server and waits for it to save. |
| `./restart.sh` | Runs `stop.sh` then `start.sh`. |
| `./update.sh` | Updates the server jar/loader (Paper or NeoForge). |
| `./forcekill.sh` | **Emergency only.** Kills the process immediately (data loss risk). |
| `./uninstall.sh` | **Danger.** Deletes the entire server folder and removes cron jobs. |

---

## 📋 Requirements

* **OS:** Debian 10+ or Ubuntu 20.04+
* **Permissions:** Root or `sudo` access (to install Java/dependencies).
