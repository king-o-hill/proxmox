#!/bin/bash

# Clone repo if it doesn't exist
if [ ! -d /root/proxmox ]; then
  git clone https://github.com/king-o-hill/proxmox.git /root/proxmox
fi

# Create symlinks
ln -sf /root/proxmox/newct.sh /usr/local/bin/newct
ln -sf /root/proxmox/destroyct.sh /usr/local/bin/destroyct

# Set execute permissions
chmod +x /root/proxmox/newct.sh /root/proxmox/destroyct.sh

echo "✅ Proxmox provisioning scripts installed."
echo "You can now use:  newct  or  destroyct  from anywhere."
