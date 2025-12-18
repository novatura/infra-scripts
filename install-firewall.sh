#!/bin/bash

# This script downloads and installs the latest scripts for firewall automation and creates their respective cron jobs.

# --- CONFIGURATION ---
REPO_OWNER="novatura"
REPO_NAME="infra-scripts"
BRANCH="main"

BASE_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"
SCRIPT_DIR="/home/forge/scripts"

# --- CHECK ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "--- Initializing Firewall Automation ---"

# 1. Create Directory
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Creating directory: $SCRIPT_DIR"
    mkdir -p "$SCRIPT_DIR"
fi

# 2. Download Scripts Function
download_script() {
    local filename=$1
    echo "Downloading $filename..."
    curl -s --fail "$BASE_URL/$filename" -o "$SCRIPT_DIR/$filename"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download $filename. Check your repo URL."
        exit 1
    fi
    
    chmod +x "$SCRIPT_DIR/$filename"
}

download_script "update-forge-ssh.sh"
download_script "update-cloudflare-firewall.sh"

# 3. Setup Cron Jobs
# Helper function to add cron only if it doesn't exist
add_cron_job() {
    local schedule=$1
    local command=$2
    local job="$schedule $command"
    
    # Check if job exists in crontab (ignoring output)
    crontab -l 2>/dev/null | grep -F "$command" >/dev/null
    
    if [ $? -eq 0 ]; then
        echo "Cron job already exists: $command"
    else
        echo "Adding Cron job: $command"
        (crontab -l 2>/dev/null; echo "$job") | crontab -
    fi
}

# Add Tailscale interface to UFW
echo "Adding Tailscale VPN rule..."
ufw allow in on tailnet0 comment 'Tailscale VPN'

# Add Cloudflare Update (Daily at 4am) - Output sent to /dev/null, errors sent to user
add_cron_job "0 4 * * *" "$SCRIPT_DIR/update-cloudflare-firewall.sh > /dev/null"

# Add Forge SSH Update (Sundays at 3am)
add_cron_job "0 3 * * 0" "$SCRIPT_DIR/update-forge-ssh.sh > /dev/null 2>&1"

# 4. Run immediately
echo "--- Running scripts for the first time ---"
bash "$SCRIPT_DIR/update-cloudflare-firewall.sh"
bash "$SCRIPT_DIR/update-forge-ssh.sh"

echo "--- Installation Complete ---"
echo "IMPORTANT: Manually verify UFW status and delete the generic 'Allow 22' rule explicitly to finish locking down SSH."
echo "1. Run 'ufw status numbered'
Verify the new commented rules exist:
    'Cloudflare IP'
    'Laravel Forge SSH'

Verify the Tailscale rule exists: 'Allow Tailscale VPN'
Delete the open holes:
    ufw delete [number] (for the generic Port 80/443 Allow rule)
    ufw delete [number] (for the generic Port 22 Allow rule)"
