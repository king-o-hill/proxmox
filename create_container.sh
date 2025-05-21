#!/bin/bash

set -e

# Validate CTID
if [[ -z "$CTID" ]]; then
  echo "❌ CTID environment variable not set."
  exit 1
fi

# Step 1: Detect base IP
HOST_IP=$(hostname -I | awk '{print $1}')
BASE_IP=$(echo "$HOST_IP" | awk -F. '{print $1 "." $2 "." $3 "."}')
read -p "🌐 Detected base IP is ${BASE_IP}. Use this? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
  read -p "Enter desired base IP (e.g. 192.168.1.): " BASE_IP
fi
STATIC_IP="${BASE_IP}${CTID}"
echo "🧠 Using static IP: $STATIC_IP"

# Step 2: Get valid storage options that support 'vztmpl'
mapfile -t TEMPLATE_STORAGES < <(pvesm status --content vztmpl | awk 'NR>1 {print $1}')

if [[ ${#TEMPLATE_STORAGES[@]} -eq 0 ]]; then
  echo "❌ No storage locations found that support container templates (vztmpl)."
  exit 1
fi

echo "📦 Available storages that support container templates:"
for i in "${!TEMPLATE_STORAGES[@]}"; do
  echo "$((i + 1))) ${TEMPLATE_STORAGES[$i]}"
done

read -p "#? " template_storage_index
TEMPLATE_STORAGE="${TEMPLATE_STORAGES[$((template_storage_index - 1))]}"

# Step 3: Locate template directory
STORAGE_PATH=$(pvesm status --storage "$TEMPLATE_STORAGE" --content vztmpl | awk 'NR==2 {print $2}')
TEMPLATE_DIR="${STORAGE_PATH}/template/cache"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "❌ Template directory not found: $TEMPLATE_DIR"
  exit 1
fi

mapfile -t TEMPLATES < <(find "$TEMPLATE_DIR" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.tar.zst' \) | xargs -n1 basename)

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  echo "❌ No container templates found in $TEMPLATE_STORAGE."
  exit 1
fi

echo "📄 Available container templates in '$TEMPLATE_STORAGE':"
for i in "${!TEMPLATES[@]}"; do
  echo "$((i + 1))) ${TEMPLATES[$i]}"
done

read -p "#? " template_index
TEMPLATE="${TEMPLATES[$((template_index - 1))]}"

# Step 4: Choose storage for container itself
mapfile -t ALL_STORAGES < <(pvesm status | awk 'NR>1 {print $1}')

echo "📂 Select storage to create container disk on:"
for i in "${!ALL_STORAGES[@]}"; do
  echo "$((i + 1))) ${ALL_STORAGES[$i]}"
done

read -p "#? " container_storage_index
CONTAINER_STORAGE="${ALL_STORAGES[$((container_storage_index - 1))]}"

# Step 5: Set default disk size
DISK_SIZE="32G"

# Step 6: Create container
echo "🚀 Creating container CT$CTID using $TEMPLATE on $CONTAINER_STORAGE..."

pct create "$CTID" "$TEMPLATE_DIR/$TEMPLATE" \
  -storage "$CONTAINER_STORAGE" \
  -hostname "ct$CTID" \
  -cores 2 \
  -memory 2048 \
  -net0 name=eth0,bridge=vmbr0,ip="$STATIC_IP"/24,gw="${BASE_IP}1" \
  -rootfs "$CONTAINER_STORAGE:$DISK_SIZE" \
  -unprivileged 1 \
  -features nesting=1 \
  -start 1

echo "✅ Container CT$CTID has been created."
