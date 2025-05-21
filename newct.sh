#!/bin/bash

# Ensure the proxmox script directory exists
cd /root/proxmox || {
  echo "❌ /root/proxmox not found. Cloning it..."
  git clone https://github.com/king-o-hill/proxmox.git /root/proxmox || exit 1
  cd /root/proxmox || exit 1
}

# Step 1: Get a valid CTID (100–250)
while true; do
  read -p "📦 Enter a new CTID (100–250): " CTID
  if [[ "$CTID" =~ ^[0-9]+$ ]] && (( CTID >= 100 && CTID <= 250 )); then
    break
  else
    echo "❌ Invalid CTID. Must be a number between 100 and 250."
  fi
done

# Step 2: Detect current IP and ask to confirm
HOST_IP=$(hostname -I | awk '{print $1}')
BASE_IP=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3"."}')
read -p "🌐 Detected base IP is $BASE_IP. Use this? [Y/n]: " use_ip
if [[ "$use_ip" =~ ^[Nn]$ ]]; then
  read -p "Enter custom base IP (e.g., 192.168.68.): " BASE_IP
fi

STATIC_IP="${BASE_IP}${CTID}"

echo "🧠 Using static IP: $STATIC_IP"

# Step 3: Run create_container.sh with CTID and IP passed as env vars
CTID="$CTID" STATIC_IP="$STATIC_IP" bash create_container.sh

# Step 4: Run setup_users.sh inside the container
echo "[*] Running setup_users.sh inside CT$CTID..."
pct exec "$CTID" -- bash -c "apt update -y && apt install curl -y && curl -sSL https://raw.githubusercontent.com/king-o-hill/proxmox/main/setup_users.sh | bash"

# Step 5: Ensure symlink exists
if [[ ! -f /usr/local/bin/newct ]]; then
  echo "🔗 Creating symlink /usr/local/bin/newct..."
  ln -s /root/proxmox/newct.sh /usr/local/bin/newct
  chmod +x /root/proxmox/newct.sh
fi

echo "✅ Container CT$CTID created and configured."
