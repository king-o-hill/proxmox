#!/bin/bash
# /etc/profile.d/first_login.sh

SENTINEL="/root/.first_login_done"

if [ ! -f "$SENTINEL" ]; then
  echo "🚀 Running first login setup..."

  if [ -x /root/setup_users.sh ]; then
    /root/setup_users.sh
  else
    echo "⚠️ setup_users.sh not found or not executable."
  fi

  touch "$SENTINEL"
  echo "✅ First login setup complete."


# Remove this script from future logins
  rm -f /etc/profile.d/first_login.sh
  rm -f /root/setup_users.sh

fi
