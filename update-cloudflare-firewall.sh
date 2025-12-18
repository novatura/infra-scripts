#!/bin/bash

# This script adds the latest Cloudflare IPs to the UFW firewall.

# Configuration
CF_URL_V4="https://www.cloudflare.com/ips-v4"
CF_URL_V6="https://www.cloudflare.com/ips-v6"
TARGET_PORT=443

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "--- Starting Cloudflare Firewall Update ---"

# 1. Fetch IPs
echo "Fetching Cloudflare IPs..."
IPS_V4=$(curl -s --fail $CF_URL_V4)
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch IPv4 list. Aborting."
    exit 1
fi

IPS_V6=$(curl -s --fail $CF_URL_V6)
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch IPv6 list. Aborting."
    exit 1
fi

# 2. Allow IPv4
echo "Updating IPv4 Rules..."
for ip in $IPS_V4; do
    # We do not specify 'proto tcp' or 'proto udp' here. 
    # By omitting it, UFW allows BOTH. This is important because 
    # Cloudflare uses UDP for HTTP/3 (QUIC) and TCP for standard HTTPS.
    ufw allow from "$ip" to any port "$TARGET_PORT" comment 'Cloudflare IP'
done

# 3. Allow IPv6
echo "Updating IPv6 Rules..."
for ip in $IPS_V6; do
    ufw allow from "$ip" to any port "$TARGET_PORT" comment 'Cloudflare IP'
done

echo "--- Update Complete. Reloading UFW. ---"
ufw reload

echo "Done."
