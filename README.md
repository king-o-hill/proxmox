# 🧰 Proxmox Container Automation

Automate the creation and provisioning of LXC containers on a Proxmox VE host. This toolkit is designed for users who prefer working within the **Proxmox Web UI and Console**, and want a fast, repeatable way to create containers with secure, preconfigured users.

---

## 📁 What's Included

| File                  | Purpose |
|-----------------------|---------|
| `newct.sh`            | **Main launcher script**: orchestrates container creation and post-setup |
| `create_container.sh` | Prompts for CTID, template, IP, CPU, RAM, swap, and storage; creates the LXC |
| `destroyct.sh`        | Prompts for CTID to destroy the container and delete unneeded elements |
| `first_run.sh`        | Clones the repo to give commands necessary to run |
| `setup_users.sh`      | Installs system updates and creates `king` and `nero` users with passwordless sudo, SSH key login, and disables password/root SSH access |
| `media/`              | Unrelated to container creation: scripts for encoding media to a direct-play format for Jellyfin/Plex. See [`media/README.md`](media/README.md) |

---

🚀 Quick Setup (First Time Install)

To install and enable the provisioning scripts on your Proxmox host:

```bash
wget -qO- https://raw.githubusercontent.com/king-o-hill/proxmox/main/first_run.sh | bash
```

This will:

    Clone the GitHub repo (if needed)

    Set up newct and destroyct global commands

    Ensure permissions are set correctly

Afterward, you can create a container using:

newct

Or destroy one safely with:

destroyct

---

## 🚀 Quick Start: Create and Provision a New Container

### 1. Run the quick setup from above or skip to step 2 if already done

2. Launch Container Creation and Setup

execute "newct" command

You will be prompted for:

    A CTID (must be between 100 and 250)

    Number of cores

    Amount of RAM

    Amount of swap

    Available template to use

    Storage to use (e.g., local-zfs)

The script will:

    Create the container with static IP 192.168.4.<CTID>/24

    Set default gateway to 192.168.4.1

    Automatically start the container

    Then install:

        Users king and nero, each with a randomly generated password

        Passwordless sudo access

        SSH key from GitHub user king-o-hill

        Disable password login and root login over SSH

        Run apt update, upgrade, and install curl, git

👥 Users Created Inside Container

| User | Password | Sudo Access | SSH Login | Passwordless |
|------|----------|-------------|-----------|--------------|
| king | generated per container | ✅ Yes | ✅ Key only | ✅ |
| nero | generated per container | ❌ No | ❌ Not provisioned with key | ✅ |

🔑 Passwords

The container root password and both user passwords are generated randomly for
each container and printed **once**, at the end of the `newct` run. They are not
stored on disk or committed anywhere — record them when they are displayed.

To set them yourself instead, export them before running:

```bash
CT_ROOT_PASSWORD='...' KING_PASSWORD='...' NERO_PASSWORD='...' newct
```

SSH access is restricted to key-based login only. You must log in as king using the SSH key fetched from GitHub.
🔐 SSH Security Defaults

    ❌ Password login over SSH is disabled

    ❌ Root login over SSH is disabled

    ✅ Public key from GitHub (king-o-hill.keys) is added to king's ~/.ssh/authorized_keys

If you want to change the key source, edit the setup_users.sh line:

```bash
curl -s https://github.com/king-o-hill.keys > /home/king/.ssh/authorized_keys
```

⚙️ Manual Options
Create Only

./create_container.sh

This will only create the container and stop after starting it.
Provision Users Only (Existing CT)

```bash
pct exec <CTID> -- bash -c "apt update -y && apt install curl -y && curl -sSL https://raw.githubusercontent.com/king-o-hill/proxmox/main/setup_users.sh | bash"
```

🗂 File Locations

Assuming the repo is cloned to /root/proxmox:
Script	Location
newct.sh	/root/proxmox/newct.sh
create_container.sh	/root/proxmox/create_container.sh
setup_users.sh	/root/proxmox/setup_users.sh

Optional: symlink newct.sh to your system path:

ln -s /root/proxmox/newct.sh /usr/local/bin/newct

Then you can run:

newct

✅ Requirements:

    Proxmox VE 7.x or 8.x

    ZFS or appropriate storage pool (e.g., local-zfs)

    LXC template already downloaded

    Internet access from containers

📌 Notes:

    Works best when run from Proxmox Web UI console

    No cloud-init is used or required

    Designed to work without needing direct SSH into host


🔗 Convenient Shortcuts (Global Commands)

After running first-run.sh, the following shortcuts will be created automatically:

newct

➡ Launches interactive container creation from a template, including user setup.

destroyct

➡ Destroys a specified container and its associated ZFS volume.

🧠 Note: These commands work globally from anywhere on the Proxmox host.
