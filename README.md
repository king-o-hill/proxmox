# 🧰 Proxmox Container Automation

Automate the creation and provisioning of LXC containers on a Proxmox VE host. This toolkit is designed for users who prefer working within the **Proxmox Web UI and Console**, and want a fast, repeatable way to create containers with secure, preconfigured users.

---

## 📁 What's Included

| File                  | Purpose |
|-----------------------|---------|
| `newct.sh`            | **Main launcher script**: orchestrates container creation and post-setup |
| `create_container.sh` | Prompts for CTID, template, IP, CPU, RAM, swap, and storage; creates the LXC |
| `destroyct.sh`        |
| `setup_users.sh`      | Installs system updates and creates `king` and `nero` users with passwordless sudo, SSH key login, and disables password/root SSH access |

---

## 🚀 Quick Start: Create and Provision a New Container

### 1. Clone the Repo on the Proxmox Host

```bash
cd /root
git clone https://github.com/king-o-hill/proxmox.git
cd proxmox
chmod +x newct.sh create_container.sh setup_users.sh

2. Launch Container Creation and Setup

./newct.sh

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

        Users king (password: REDACTED) and nero (password: REDACTED)

        Passwordless sudo access

        SSH key from GitHub user king-o-hill

        Disable password login and root login over SSH

        Run apt update, upgrade, and install curl, git

👥 Users Created Inside Container
User	Password	Sudo Access	SSH Login	Passwordless
king	REDACTED	✅ Yes	✅ Key only	✅
nero	REDACTED	❌ No	❌ Not provisioned with key	✅

SSH access is restricted to key-based login only. You must log in as king using the SSH key fetched from GitHub.
🔐 SSH Security Defaults

    ❌ Password login over SSH is disabled

    ❌ Root login over SSH is disabled

    ✅ Public key from GitHub (king-o-hill.keys) is added to king's ~/.ssh/authorized_keys

If you want to change the key source, edit the setup_users.sh line:

curl -s https://github.com/king-o-hill.keys > /home/king/.ssh/authorized_keys

⚙️ Manual Options
Create Only

./create_container.sh

This will only create the container and stop after starting it.
Provision Users Only (Existing CT)

pct exec <CTID> -- bash -c "apt update -y && apt install curl -y && curl -sSL https://raw.githubusercontent.com/king-o-hill/proxmox/main/setup_users.sh | bash"

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

💾 Pushing Changes to GitHub

GitHub no longer supports password authentication for pushes.
1. Generate a Personal Access Token (PAT)

    Go to GitHub Tokens Settings

    Click "Generate new token (classic)"

    Check repo scope

    Copy the token (you won't see it again!)

2. Push with Token

git add README.md
git commit -m "Add full updated README with setup instructions"
git push https://king-o-hill:<your_token>@github.com/king-o-hill/proxmox.git

✅ Requirements

    Proxmox VE 7.x or 8.x

    ZFS or appropriate storage pool (e.g., local-zfs)

    LXC template already downloaded

    Internet access from containers

📌 Notes

    Works best when run from Proxmox Web UI console

    No cloud-init is used or required

    Designed to work without needing direct SSH into host


</details>

---

### ✅ STEP 2: Save the File in Nano

Once pasted into `nano`, do:

- Press `Ctrl + O`, then `Enter` (to save)
- Press `Ctrl + X` (to exit)

---

### ✅ STEP 3: Push to GitHub

If you haven't already, generate a **Personal Access Token (PAT)** from GitHub with `repo` access:  
👉 [https://github.com/settings/tokens](https://github.com/settings/tokens)

Now, push the updated README file:

```bash
cd /root/proxmox
git add README.md
git commit -m "Add complete and formatted README"
git push https://king-o-hill:<your_token>@github.com/king-o-hill/proxmox.git

Replace <your_token> with your actual PAT.


🔗 Convenient Shortcuts (Global Commands)

After running first-run.sh, the following shortcuts will be created automatically:

newct

➡ Launches interactive container creation from a template, including user setup.

destroyct

➡ Destroys a specified container and its associated ZFS volume.

🧠 Note: These commands work globally from anywhere on the Proxmox host.
