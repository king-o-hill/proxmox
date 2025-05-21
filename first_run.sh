#!/bin/bash

REPO_URL="https://github.com/king-o-hill/proxmox.git"
INSTALL_DIR="/root/proxmox"

echo "📦 Cloning or updating Proxmox provisioning repo..."

if [ -d "$INSTALL_DIR/.git" ]; then
  git -C "$INSTALL_DIR" pull --rebase
else
  rm -rf "$INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo "🔧 Setting permissions..."
chmod +x "$INSTALL_DIR"/*.sh

echo "🔗 Creating or updating symlinks..."
ln -sf "$INSTALL_DIR/newct.sh" /usr/local/bin/newct
ln -sf "$INSTALL_DIR/destroyct.sh" /usr/local/bin/destroyct

echo "✅ Proxmox provisioning tools installed!"
echo "🟢 You can now use:"
echo "   👉  newct"
echo "   👉  destroyct"
