#!/bin/bash

REPO_URL="https://github.com/king-o-hill/proxmox.git"
INSTALL_DIR="/root/proxmox"

echo "📦 Cloning or updating Proxmox provisioning repo..."

# Delete and re-clone to guarantee a clean install
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"

echo "🔧 Setting permissions on all scripts..."
chmod +x "$INSTALL_DIR"/*.sh

echo "🔗 Creating or fixing symlinks..."
ln -sf "$INSTALL_DIR/newct.sh" /usr/local/bin/newct
ln -sf "$INSTALL_DIR/destroyct.sh" /usr/local/bin/destroyct

echo "✅ Proxmox provisioning tools installed!"
echo
echo "🟢 You can now use:"
echo "   👉  newct"
echo "   👉  destroyct"
