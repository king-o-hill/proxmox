#!/bin/bash

set -e

echo "🛠 Running system updates and installing curl & git..."

apt update && apt upgrade -y
apt install -y curl git

create_user() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local GROUPNAME="$USERNAME"
    local SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

    echo "👤 Creating user: $USERNAME"

    # Create group if it doesn't exist
    if ! getent group "$GROUPNAME" > /dev/null; then
        groupadd "$GROUPNAME"
    fi

    # Create user if it doesn't exist
    if ! id "$USERNAME" > /dev/null 2>&1; then
        useradd -m -s /bin/bash -g "$GROUPNAME" -G sudo "$USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
        chmod 0440 "$SUDOERS_FILE"
        echo "✅ User '$USERNAME' created with sudo access and password set."
    else
        echo "⚠️ User '$USERNAME' already exists. Skipping creation."
    fi
}

create_user "king" "95Firehawk!"
create_user "nero" "tachibana"

echo "🔒 Hardening SSH config..."

SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# Set SSH options
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG"

# Ensure entries exist if missing
grep -q '^PermitRootLogin' "$SSHD_CONFIG" || echo 'PermitRootLogin no' >> "$SSHD_CONFIG"
grep -q '^PasswordAuthentication' "$SSHD_CONFIG" || echo 'PasswordAuthentication no' >> "$SSHD_CONFIG"

# Restart SSH
systemctl restart sshd
echo "✅ SSH hardened: root login and password auth disabled."

echo "🎉 All done! Users 'king' and 'nero' are set up."
