#!/bin/bash

# Location of hook script if you want to auto-bootstrap
HOOK_SCRIPT="/var/lib/lxc/lxc-user-bootstrap-hook.sh"

echo "🔧 Proxmox LXC Auto-Creation Script"

# Prompt for CT ID
read -p "Enter Container ID (e.g. 101): " CTID
read -p "Enter Hostname: " HOSTNAME

# Prompt for Cores, RAM, Swap
read -p "Enter number of CPU cores: " CORES
read -p "Enter RAM (MB): " MEMORY
read -p "Enter Swap (MB): " SWAP

# Show available storage options
echo "📦 Available Storages:"
pvesm status | awk 'NR>1 {print $1}'
read -p "Enter storage to use (as listed above): " STORAGE

# Show available templates
echo "📦 Available Templates:"
pveam available | grep -v "\[local\]" | awk '{print $2}' | nl
read -p "Enter template name (e.g., debian-12-standard_*.tar.zst): " TEMPLATE

# Pull latest template if not present
if ! ls /var/lib/vz/template/cache/"$TEMPLATE" &> /dev/null; then
  echo "📥 Downloading template..."
  pveam download local "$TEMPLATE"
fi

# Build static IP
STATIC_IP="192.168.4.$CTID/24"
GATEWAY="192.168.4.1"

echo "🛠 Creating container $CTID ($HOSTNAME) with static IP $STATIC_IP"

pct create $CTID local:vztmpl/"$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --net0 name=eth0,bridge=vmbr0,ip=$STATIC_IP,gw=$GATEWAY \
  --rootfs ${STORAGE}:32 \
  --password 95Firehawk! \
  --unprivileged 1 \
  --features nesting=1 \
  --hookscript $HOOK_SCRIPT

echo "✅ Container $CTID created."
echo "➡️ You can now start it with: pct start $CTID"
