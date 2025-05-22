#!/bin/bash

set -e

echo "🛠 Running system updates and installing curl & git..."
apt update && apt upgrade -y
apt install -y curl git

create_user() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

    echo "👤 Creating user: $USERNAME"

    if id "$USERNAME" &>/dev/null; then
        echo "⚠️ User '$USERNAME' already exists. Skipping creation."
        return
    fi

    # Create user with disabled password (we'll set it manually)
    adduser --disabled-password --gecos "" "$USERNAME"

    # Set password
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Add to sudo group
    usermod -aG sudo "$USERNAME"

    # Passwordless sudo
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"

    echo "✅ User '$USERNAME' created with sudo access and password set."
}

create_user "king" "95Firehawk!"
create_user "nero" "tachibana"

echo "🔒 Hardening SSH config..."
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# Apply or append SSH hardening settings
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG" || true
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG" || true

grep -q '^PermitRootLogin' "$SSHD_CONFIG" || echo 'PermitRootLogin no' >> "$SSHD_CONFIG"
grep -q '^PasswordAuthentication' "$SSHD_CONFIG" || echo 'PasswordAuthentication no' >> "$SSHD_CONFIG"

# Restart SSH
systemctl restart sshd
echo "✅ SSH hardened: root login and password auth disabled."

echo "🎉 All done! Users 'king' and 'nero' are set up."
