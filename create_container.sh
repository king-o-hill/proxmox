#!/bin/bash

# Ensure we're root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root."
  exit 1
fi

# CTID
read -p "📦 Enter a new CTID (100–250): " CTID

# Detect base IP and allow override
host_ip=$(hostname -I | awk '{print $1}')
base_ip=$(echo "$host_ip" | awk -F. '{print $1"."$2"."$3"."}')
read -p "🌐 Detected base IP is ${base_ip}. Use this? [Y/n]: " use_base
if [[ "$use_base" =~ ^[Nn] ]]; then
  read -p "🔧 Enter base IP (e.g., 192.168.1.): " base_ip
fi
ip="${base_ip}${CTID}"
echo "🧠 Using static IP: $ip"

# List storages that allow container templates (vztmpl)
echo "📦 Available storages that support container templates:"
mapfile -t TEMPLATE_STORAGES < <(pvesm status --verbose | awk '/vztmpl/ {print $1}')
if [[ ${#TEMPLATE_STORAGES[@]} -eq 0 ]]; then
  echo "❌ No storages support container templates."
  exit 1
fi

select TEMPLATE_STORAGE in "${TEMPLATE_STORAGES[@]}"; do
  [[ -n "$TEMPLATE_STORAGE" ]] && break
  echo "❌ Invalid selection."
done

# Locate template path
TEMPLATE_PATH=$(pvesm path "${TEMPLATE_STORAGE}:vztmpl" 2>/dev/null || echo "/var/lib/vz/template/cache")
TEMPLATE_DIR="${TEMPLATE_PATH%:*}/template/cache"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "❌ Template directory not found: $TEMPLATE_DIR"
  exit 1
fi

echo "📄 Available container templates in '${TEMPLATE_STORAGE}':"
mapfile -t TEMPLATES < <(ls "$TEMPLATE_DIR" 2>/dev/null | grep '\.tar\.' || true)
if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  echo "❌ No container templates found in $TEMPLATE_STORAGE."
  exit 1
fi

select TEMPLATE in "${TEMPLATES[@]}"; do
  [[ -n "$TEMPLATE" ]] && break
  echo "❌ Invalid selection."
done

# Pick container storage
echo "💾 Available storages that support containers:"
mapfile -t CONTAINER_STORAGES < <(pvesm status | awk '$5 ~ /rootdir/ {print $1}')
if [[ ${#CONTAINER_STORAGES[@]} -eq 0 ]]; then
  echo "❌ No storages support rootfs (container storage)."
  exit 1
fi

select CONTAINER_STORAGE in "${CONTAINER_STORAGES[@]}"; do
  [[ -n "$CONTAINER_STORAGE" ]] && break
  echo "❌ Invalid selection."
done

# Disk size
read -p "💾 Enter container disk size in GB [Default: 32]: " DISK_SIZE
DISK_SIZE="${DISK_SIZE:-32}"

# Create container
echo "⚙️ Creating container CT$CTID..."
pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
  -storage "$CONTAINER_STORAGE" \
  -hostname "ct$CTID" \
  -net0 "name=eth0,bridge=vmbr0,ip=${ip}/24,gw=${base_ip}1" \
  -rootfs "${CONTAINER_STORAGE}:${DISK_SIZE}" \
  -memory 2048 \
  -cores 2 \
  -password "proxmox" \
  -unprivileged 1 || {
    echo "❌ Failed to create container."
    exit 1
  }

pct start "$CTID"

# Optional post-setup
if [[ -f "/root/proxmox/setup_users.sh" ]]; then
  echo "[*] Running setup_users.sh inside CT$CTID..."
  pct exec "$CTID" -- bash -c "/root/setup_users.sh"
fi

echo "✅ Container CT$CTID created and configured."
