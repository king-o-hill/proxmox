#!/bin/bash

# Ensure CTID is passed from environment
if [[ -z "$CTID" ]]; then
  echo "❌ CTID not provided. Run this script via newct.sh."
  exit 1
fi

# === Template Storage Selection ===
echo "📦 Available storages that support container templates:"
mapfile -t template_storages < <(pvesm status -content vztmpl | awk 'NR>1 {print $1}')
if [[ ${#template_storages[@]} -eq 0 ]]; then
  echo "❌ No storage with container templates available."
  exit 1
fi

select tmpl_storage in "${template_storages[@]}"; do
  [[ -n "$tmpl_storage" ]] && break
  echo "Invalid selection."
done

# === List downloaded templates ===
echo "📄 Available container templates in '$tmpl_storage':"
mapfile -t templates < <(pvesm list "$tmpl_storage" | awk '$2 == "vztmpl" {print $1}' | sort)
if [[ ${#templates[@]} -eq 0 ]]; then
  echo "❌ No container templates found in $tmpl_storage."
  exit 1
fi

select template in "${templates[@]}"; do
  [[ -n "$template" ]] && break
  echo "Invalid selection."
done

# === Container Storage Selection ===
echo "💾 Available storages for container root disk:"
mapfile -t rootfs_storages < <(pvesm status -content rootdir | awk 'NR>1 {print $1}')
if [[ ${#rootfs_storages[@]} -eq 0 ]]; then
  echo "❌ No storage found for rootdir."
  exit 1
fi

select rootfs_storage in "${rootfs_storages[@]}"; do
  [[ -n "$rootfs_storage" ]] && break
  echo "Invalid selection."
done

# === Container Configuration ===
read -p "🧠 Number of cores: " CORES
read -p "🧠 Memory (MB): " MEMORY
read -p "💾 Swap (MB): " SWAP
read -p "💽 Disk size in GB (default 32): " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-32}

# === Auto-generate IP address ===
host_ip=$(hostname -I | awk '{print $1}')
base_ip="${host_ip%.*}."
suggested_ip="${base_ip}${CTID}"

read -p "🌐 Suggested IP: ${suggested_ip}. Use this? (Y/n): " use_suggested
if [[ "$use_suggested" =~ ^[Nn]$ ]]; then
  read -p "Enter custom IP: " ip
else
  ip="$suggested_ip"
fi

# === Check if IP is available ===
if ping -c1 -W1 "$ip" &>/dev/null; then
  echo "❌ IP $ip is already in use."
  exit 1
fi

# === Create the container ===
echo "🚀 Creating container CT$CTID..."
pct create "$CTID" "${tmpl_storage}:vztmpl/${template}" \
  -storage "$rootfs_storage" \
  -cores "$CORES" \
  -memory "$MEMORY" \
  -swap "$SWAP" \
  -rootfs "${rootfs_storage}:$DISK_SIZE" \
  -net0 name=eth0,ip=${ip}/24,gw=${base_ip}1,bridge=vmbr0 \
  -hostname "ct${CTID}" \
  -features nesting=1 \
  -unprivileged 1 \
  -onboot 1

echo "✅ Container CT$CTID created at IP $ip"
