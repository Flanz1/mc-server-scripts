# Use Java 21 (Official lightweight image)
FROM eclipse-temurin:21-jdk-jammy

# Install dependencies required by your scripts
# - screen: The core of your dashboard
# - jq: For JSON parsing (updates)
# - curl/wget: Downloading files
# - procps: For 'ps' and 'pgrep' commands
# - cron: For your auto-backups
RUN apt-get update && apt-get install -y \
    screen \
    jq \
    curl \
    wget \
    unzip \
    cron \
    procps \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create server directory
WORKDIR /data

# Copy your installer into the image
COPY install.sh /opt/install.sh
RUN chmod +x /opt/install.sh

# Copy a wrapper script (we'll create this next)
COPY docker-entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Expose Minecraft Port
EXPOSE 25565

# Define Environment Variables (Can be overridden in docker-compose)
ENV RAM=4G
ENV SERVER_TYPE=1
ENV EULA=true

# Set the entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]
