#!/bin/bash

# Step 1: Ensure the proxmox script directory exists
cd /root/proxmox || {
  echo "❌ /root/proxmox not found. Cloning it..."
  git clone https://github.com/king-o-hill/proxmox.git /root/proxmox || exit 1
  cd /root/proxmox || exit 1
}

# Step 2: Run create_container.sh with CTID and IP passed as env vars
bash create_container.sh

# Step 3: Ensure symlink exists
if [[ ! -f /usr/local/bin/newct ]]; then
  echo "🔗 Creating symlink /usr/local/bin/newct..."
  ln -s /root/proxmox/newct.sh /usr/local/bin/newct
  chmod +x /root/proxmox/newct.sh
fi

echo "✅ Container CT$CTID created and configured."
