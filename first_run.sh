#!/bin/bash

# Auto-clone the repo to /root/proxmox if it doesn't exist
if [ ! -d /root/proxmox ]; then
  echo "📦 Cloning proxmox provisioning repo..."
  git clone https://github.com/king-o-hill/proxmox.git /root/proxmox || {
    echo "❌ Failed to clone repository. Check your internet or GitHub access."
    exit 1
  }
fi

# Create or refresh symlinks
ln -sf /root/proxmox/newct.sh /usr/local/bin/newct
ln -sf /root/proxmox/destroyct.sh /usr/local/bin/destroyct

# Ensure scripts are executable
chmod +x /root/proxmox/newct.sh /root/proxmox/destroyct.sh

echo "✅ Proxmox provisioning scripts installed."
echo "🟢 You can now use:  newct   or   destroyct"
