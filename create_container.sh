#!/bin/bash

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

echo -e "${CYAN}📦 Enter a new CTID (100–250):${RESET} "
read -r CTID

if [[ ! "$CTID" =~ ^1[0-9]{2}$|^2[0-4][0-9]$|^250$ ]]; then
  echo -e "${RED}❌ Invalid CTID. Must be between 100–250.${RESET}"
  exit 1
fi

# Static IP base detection
HOST_IP=$(hostname -I | awk '{print $1}')
BASE_IP=$(echo "$HOST_IP" | awk -F. '{print $1 "." $2 "." $3 "."}')
echo -e "${CYAN}🌐 Detected base IP is ${BASE_IP}. Use this? [Y/n]:${RESET} "
read -r CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
  echo -e "${CYAN}🔧 Enter base IP (e.g., 192.168.68.):${RESET} "
  read -r BASE_IP
fi
IP="${BASE_IP}${CTID}"
echo -e "${YELLOW}🧠 Using static IP: $IP${RESET}"

# List templates
TEMPLATE_DIR="/var/lib/vz/template/cache"
TEMPLATES=($(find "$TEMPLATE_DIR" -maxdepth 1 -type f -name "*.tar.zst" -printf "%f\n" | sort))
if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  echo -e "${RED}❌ No container templates found in $TEMPLATE_DIR.${RESET}"
  exit 1
fi

echo -e "${CYAN}📄 Available container templates:${RESET}"
for i in "${!TEMPLATES[@]}"; do
  echo "$((i+1))) ${TEMPLATES[$i]}"
done
read -p "#? " TEMPLATE_INDEX
TEMPLATE="${TEMPLATES[$((TEMPLATE_INDEX-1))]}"
if [[ -z "$TEMPLATE" ]]; then
  echo -e "${RED}❌ Invalid template selection.${RESET}"
  exit 1
fi
echo -e "${YELLOW}📦 Selected template: $TEMPLATE${RESET}"

# Select target storage for container
echo -e "${CYAN}📂 Available storages for container creation:${RESET}"
STORAGES=($(pvesm status | awk 'NR>1 {print $1}' | sort -u))
for i in "${!STORAGES[@]}"; do
  echo "$((i+1))) ${STORAGES[$i]}"
done
read -p "#? " STORAGE_INDEX
STORAGE="${STORAGES[$((STORAGE_INDEX-1))]}"
if [[ -z "$STORAGE" ]]; then
  echo -e "${RED}❌ Invalid storage selection.${RESET}"
  exit 1
fi
echo -e "${YELLOW}🗃️ Selected target storage: $STORAGE${RESET}"

read -rp "🖥️ Enter hostname for the container: " HOSTNAME

# Create container
echo -e "${CYAN}⚙️ Creating LXC container CT${CTID}...${RESET}"
CREATE_OUTPUT=$(pct create "$CTID" "$TEMPLATE_DIR/$TEMPLATE" \
  -storage "$STORAGE" \
  -hostname "$HOSTNAME" \
  -net0 "name=eth0,ip=$IP/24,gw=${BASE_IP}1,bridge=vmbr0" \
  -password "95Firehawk!" \
  -cores 2 \
  -memory 2048 \
  -rootfs "$STORAGE:32" \
  -unprivileged 1 \
  -features nesting=1 2>&1)

if echo "$CREATE_OUTPUT" | grep -q "unable to"; then
  echo -e "${RED}❌ Failed to create container CT${CTID}${RESET}"
  echo "$CREATE_OUTPUT"
  exit 1
fi

read -p "🚀 Start container now? Y/n]: " STARTNOW
START_NOW=${START_NOW:-Y}

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
  echo "🚀 Starting container CT$CTID..."
  pct start $CTID
  echo "📤gWaiting for container CT$CTID to start up"
  sleep 12

  echo "📤 Pushing setup scripts into container CT$CTID..."

if [[ -f "$CLONE_DIR/first_login.sh" ]]; then
  pct push $CTID "$CLONE_DIR/first_login.sh" /etc/profile.d/first_login.sh -perms 0755
  sleep 2
  pct exec $CTID -- chmod +x /etc/profile.d/first_login.sh
else
  echo "⚠️ first_login.sh not found. Skipping push."
fi

if [[ -f "$CLONE_DIR/setup_users.sh" ]]; then
  pct push $CTID "$CLONE_DIR/setup_users.sh" /root/setup_users.sh -perms 0755
  sleep 2
  pct exec $CTID -- chmod +x /root/setup_users.sh
else
  echo "⚠️ setup_users.sh not found. Skipping push."
fi


  # Push keys
#  pct push $CTID first_login.sh /etc/profile.d/first_login.sh
#  pct exec $CTID -- chmod +x /etc/profile.d/first_login.sh
#  pct push $CTID setup_users.sh /root/setup_users.sh
#  pct exec $CTID -- chmod +x /root/setup_users.sh
  pct push $CTID /keys/king/id_ed25519.pub /root/king.pub
  pct push $CTID /keys/nero/id_ed25519.pub /root/nero.pub


  # Ensure /root/.bashrc sources profile scripts (if not already doing so)
  pct exec "$CTID" -- bash -c "grep -qxF 'source /etc/profile' /root/.bashrc || echo 'source /etc/profile' >> /root/.bashrc"

  # Create symlink for 'users' command
  pct exec $CTID -- ln -sf /root/setup_users.sh /usr/local/bin/users

  echo "✅ Container CT$CTID created and configured."
else
  echo "⚠️ Skipping container start. You must start CT$CTID manually and run /root/first_run.sh inside it to complete setup."
fi

