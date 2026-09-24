#!/bin/bash
set -e

echo "👥 Setting up users and SSH keys..."

# Read the pushed pubkeys (from create_container.sh)
KING_KEY=$(cat /root/king.pub)
NERO_KEY=$(cat /root/nero.pub)

# Passwords come from create_container.sh via the pushed credentials file, or
# from the environment when this script is run on its own. If neither supplies
# them, generate throwaway ones and print them — never ship a known default.
CRED_FILE="/root/.ct_credentials"
CREDS_SUPPLIED=0
if [[ -f "$CRED_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CRED_FILE"
    CREDS_SUPPLIED=1
elif [[ -n "${KING_PASSWORD:-}" && -n "${NERO_PASSWORD:-}" ]]; then
    CREDS_SUPPLIED=1
fi

gen_password() { tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20; }
KING_PASSWORD="${KING_PASSWORD:-$(gen_password)}"
NERO_PASSWORD="${NERO_PASSWORD:-$(gen_password)}"

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

create_user "king" "$KING_PASSWORD" "$KING_KEY"
create_user "nero" "$NERO_PASSWORD" "$NERO_KEY"

if [[ "$CREDS_SUPPLIED" -eq 0 ]]; then
    echo
    echo "🔑 Generated user passwords — save these now, they are not stored:"
    echo "   king : $KING_PASSWORD"
    echo "   nero : $NERO_PASSWORD"
    echo
fi

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
