#!/bin/bash

set -e

REPO_URL="https://github.com/king-o-hill/proxmox"
CLONE_DIR="/root/proxmox"

echo "📦 Cloning or updating Proxmox provisioning repo..."

if [ -d "$CLONE_DIR/.git" ]; then
  git -C "$CLONE_DIR" pull --quiet
else
  git clone --quiet "$REPO_URL" "$CLONE_DIR"
fi

sleep 3

echo "🔧 Setting permissions on all scripts..."
chmod +x "$CLONE_DIR"/*.sh

# Remove broken symlinks if they exist
for cmd in newct destroyct; do
    LINK="/usr/local/bin/$cmd"
    [ -L "$LINK" ] && [ ! -e "$LINK" ] && rm "$LINK"
done

sleep 3

echo "🔗 Creating or fixing symlinks..."
ln -sf "$CLONE_DIR/create_container.sh" /usr/local/bin/newct
ln -sf "$CLONE_DIR/destroyct.sh" /usr/local/bin/destroyct

sleep 3

chmod +x /usr/local/bin/newct
chmod +x /usr/local/bin/destroyct

echo "✅ Proxmox provisioning tools installed!"

echo
echo "🟢 You can now use:"
echo "   👉  newct"
echo "   👉  destroyct"
