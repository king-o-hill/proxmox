#!/bin/bash

# Ensure we're in the script directory
cd "$(dirname "$0")" || exit 1

# Require CTID from environment
if [[ -z "$CTID" ]]; then
  echo "❌ CTID environment variable not set. Run from newct.sh or export CTID manually."
  exit 1
fi

# Get list of storage backends that support container images
mapfile -t STORAGE_LIST < <(pvesm status -content rootdir | awk 'NR>1 {print $1}')

if [[ ${#STORAGE_LIST[@]} -eq 0 ]]; then
  echo "❌ No storage backends found that support container rootdir."
  exit 1
fi

echo "Select storage:"
for i in "${!STORAGE_LIST[@]}"; do
  echo "  $((i+1))) ${STORAGE_LIST[$i]}"
done

read -rp "Enter a number [1-${#STORAGE_LIST[@]}]: " storage_index
STORAGE="${STORAGE_LIST[$((storage_index-1))]}"

# Get template list
mapfile -t TEMPLATES < <(pveam list "$STORAGE" | awk 'NR>1 {print $2}' | grep -vE '(^$|^\s+)')

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  echo "❌ No templates found in storage '$STORAGE'. Download one via PVE UI or 'pveam download'."
  exit 1
fi

echo "Select template:"
for i in "${!TEMPLATES[@]}"; do
  echo "  $((i+1))) ${TEMPLATES[$i]}"
done

read -rp "Enter a number [1-${#TEMPLATES[@]}]: " template_index
TEMPLATE="${TEMPLATES[$((template_index-1))]}"

# Prompt for CPU, RAM, and SWAP
read -rp "Number of cores [default: 2]: " CORES
CORES="${CORES:-2}"

read -rp "RAM in MB [default: 2048]: " MEMORY
MEMORY="${MEMORY:-2048}"

read -rp "SWAP in MB [default: 512]: " SWAP
SWAP="${SWAP:-512}"

# Auto-detect host IP subnet
BASE_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.')[]
DEFAULT_IP="${BASE_IP}${CTID}"

read -rp "Use static IP [default: $DEFAULT_IP]: " STATIC_IP
STATIC_IP="${STATIC_IP:-$DEFAULT_IP}"

# Confirm network
GATEWAY="${BASE_IP}1"

echo "📦 Creating container CT$CTID..."

pct create "$CTID" "$STORAGE:vztmpl/$TEMPLATE" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --net0 "name=eth0,ip=${STATIC_IP}/24,gw=${GATEWAY}" \
  --hostname "ct$CTID" \
  --rootfs "$STORAGE:32" \
  --unprivileged 1 \
  --features "nesting=1" \
  --start 1

echo "✅ Container CT$CTID created with static IP $STATIC_IP"
