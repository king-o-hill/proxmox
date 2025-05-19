# proxmox
Promox Utilities

# Proxmox Container User Setup

This script automates the following tasks for a Proxmox LXC container:

- Creates users `king` and `nero` with specified passwords.
- Adds users to their own groups and the `sudo` group.
- Configures passwordless `sudo` access.
- Disables root SSH login and password authentication.
- Updates the system and installs `curl` and `git`.

## Usage

Run the script inside the container:

```bash
sudo ./setup_users.sh
