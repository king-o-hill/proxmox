#!/bin/bash

# Ensure a CTID was passed
if [[ -z "$CTID" ]]; then
  echo "❌ CTID is not set. Run this script using: CTID=123 ./create_container.sh"
  exit 1
fi

# Detect host IP and suggest base IP
HOST_IP=$(hostname -I | awk '{print $1}')
DEFAULT_BASE_IP=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3}')
read -p "Detected base IP as $DEFAULT_BASE_IP. Use this? [Y/n]: " USE_DEFAULT

if [[ "$USE_DEFAULT" =~ ^[Nn]$ ]]; then
  while true; do
    read -p "Enter base IP (e.g., 192.168.68): " CUSTOM_BASE_IP
    if [[ "$CUSTOM_BASE_IP" =~ ^([0-9]{1,3}\.){2}[0-9]{1,3}$ ]]; then
      BASE_IP="$CUSTOM_BASE_IP"
      break
    else
      echo "❌ Invalid format. Must be like 192.168684"
    fi
  done
else
  BASE_IP="$DEFAULT_BASE_IP"
fi

# Compose full IP address
STATIC_IP="${BASE_IP}.${CTID}"
GATEWAY="${BASE_IP}.1"

# Check if the IP is already in use
ping -c 1 -W 1 "$STATIC_IP" &>/dev/null
if [[ $? -eq 0 ]]; then
  echo "⚠️ IP $STATIC_IP is responding to ping. It might be in use."
  read -p "Continue anyway? [y/N]: " PROCEED
  if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  fi
fi

# Prompt for container config
read -p "Enter hostname: " HOSTNAME
read -p "Enter number of cores: " CORES
read -p "Enter amount of RAM (MB): " MEMORY
read -p "Enter amount of SWAP (MB): " SWAP
read -p "Enter storage (e.g., local-lvm): " STORAGE
read -p "Choose template (e.g., debian-12-standard_12.2-1_amd64.tar.zst): " TEMPLATE

# Create the container
pct create "$CTID" "/var/lib/vz/template/cache/$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --net0 "name=eth0,ip=${STATIC_IP}/24,gw=${GATEWAY}" \
  --ostype debian \
  --storage "$STORAGE" \
  --rootfs "$STORAGE":32 \
  --password "95Firehawk!" \
  --unprivileged 1

pct start "$CTID"
echo "✅ Container $CTID created with IP $STATIC_IP"
