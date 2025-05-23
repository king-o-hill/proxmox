#!/bin/bash

# destroyct.sh - Safely destroy a Proxmox container by CTID

read -p "Enter the CTID to destroy (100–250): " CTID

# Validate input
if ! [[ "$CTID" =~ ^[0-9]+$ ]] || (( CTID < 100 || CTID > 250 )); then
  echo "❌ Invalid CTID. Must be a number between 100 and 250."
  exit 1
fi

# Check if container exists
if ! pct status "$CTID" &>/dev/null; then
  echo "❌ CT$CTID does not exist."
  exit 1
fi

echo "⚠️ This will completely destroy CT$CTID and its data."
read -p "Are you sure? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

# Stop container if running
if pct status "$CTID" | grep -q "running"; then
  echo "⏹️ Stopping container CT$CTID..."
  pct stop "$CTID"
  sleep 10
fi

# Destroy the container
echo "💣 Destroying container CT$CTID..."
pct destroy "$CTID"

echo "🧹 Cleaning up ZFS volumes if any..."

# Attempt to destroy related ZFS volume
if zfs list | grep -q "subvol-$CTID-disk-0"; then
  zfs destroy -r "rpool/data/subvol-$CTID-disk-0"
  echo "🗑️ ZFS subvol-$CTID-disk-0 destroyed."
fi

echo "✅ CT$CTID destroyed successfully."
