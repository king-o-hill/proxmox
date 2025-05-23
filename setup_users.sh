#!/bin/bash
set -e

echo "👥 Setting up users and SSH keys..."

# Read the pushed pubkeys (from create_container.sh)
KING_KEY=$(cat /root/king.pub)
NERO_KEY=$(cat /root/nero.pub)

create_user() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local PUBKEY="$3"

    echo "👤 Creating user: $USERNAME"

    if ! id "$USERNAME" &>/dev/null; then
        adduser --disabled-password --gecos "" "$USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
        usermod -aG sudo "$USERNAME"
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USERNAME"
        chmod 0440 "/etc/sudoers.d/$USERNAME"

        mkdir -p "/home/$USERNAME/.ssh"
        echo "$PUBKEY" > "/home/$USERNAME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
        chmod 700 "/home/$USERNAME/.ssh"
        chmod 600 "/home/$USERNAME/.ssh/authorized_keys"

        echo "✅ User '$USERNAME' created with sudo and SSH key."
    else
        echo "⚠️ User '$USERNAME' already exists. Skipping."
    fi
}

create_user "king" "95Firehawk!" "$KING_KEY"
create_user "nero" "tachibana" "$NERO_KEY"

# SSH hardening
echo "🔒 Hardening SSH config..."
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG"

grep -q '^PermitRootLogin' "$SSHD_CONFIG" || echo 'PermitRootLogin no' >> "$SSHD_CONFIG"
grep -q '^PasswordAuthentication' "$SSHD_CONFIG" || echo 'PasswordAuthentication no' >> "$SSHD_CONFIG"

systemctl restart sshd
echo "✅ SSH config hardened."
