#!/bin/bash

echo "📦 Cloning proxmox provisioning repo..."

# Clone if missing
if [ ! -d "/root/proxmox" ]; then
  git clone https://github.com/king-o-hill/proxmox.git /root/proxmox
else
  echo "📁 /root/proxmox already exists. Skipping clone."
fi

cd /root/proxmox || { echo "❌ Failed to access /root/proxmox"; exit 1; }

# Make scripts executable
chmod +x newct.sh destroyct.sh || echo "⚠️ One or more scripts missing."

# Create symlinks
ln -sf /root/proxmox/newct.sh /usr/local/bin/newct
ln -sf /root/proxmox/destroyct.sh /usr/local/bin/destroyct

echo "✅ Proxmox provisioning scripts installed."
echo "🟢 You can now use:  newct   or   destroyct"
