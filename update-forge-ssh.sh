#!/bin/bash

# This script adds the latest Forge SSH IPs to the UFW firewall.

# Configuration
FORGE_URL_V4="https://forge.laravel.com/ips-v4.txt"
FORGE_URL_V6="https://forge.laravel.com/ips-v6.txt"
SSH_PORT=22

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "--- Starting Forge SSH Firewall Update ---"

# 1. Fetch IPs
echo "Fetching Forge IPs..."
IPS_V4=$(curl -s --fail $FORGE_URL_V4)
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch IPv4 list. Aborting to prevent lockout."
    exit 1
fi

IPS_V6=$(curl -s --fail $FORGE_URL_V6)
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch IPv6 list. Aborting to prevent lockout."
    exit 1
fi

# 2. Allow IPv4
echo "Updating IPv4 Rules..."
for ip in $IPS_V4; do
    # 'limit' is often safer for SSH, but 'allow' is standard for trusted automated IPs
    ufw allow from "$ip" to any port "$SSH_PORT" proto tcp comment 'Laravel Forge SSH'
done

# 3. Allow IPv6
echo "Updating IPv6 Rules..."
for ip in $IPS_V6; do
    ufw allow from "$ip" to any port "$SSH_PORT" proto tcp comment 'Laravel Forge SSH'
done

echo "--- Update Complete. Reloading UFW. ---"
ufw reload

echo "Done."
