# mDNS Manager by Krishna

A lightweight terminal-based manager for publishing `.local` hostnames on a local network using **Avahi**.

Manage your local mDNS hostnames from a simple interactive TUI — without manually configuring DNS on every device.

---

## ✨ Features

* 🖥️ Interactive terminal UI
* 📡 Publish `.local` hostnames using Avahi
* ▶️ Start and stop publishers
* 🔄 Reload hostname configuration
* ♻️ Restart publishers
* ✏️ Edit hosts directly from the TUI
* 📋 View configured hosts
* 📊 View publisher and Avahi status
* 🚀 Optional systemd boot persistence
* 💾 Preserves publisher state across reboots
* 📦 Portable — move the entire project directory to another server
* 🔒 Only manages its own systemd service

---

## 📸 Interface

```text
╭──────────────────────────────────────────────╮
│                 mDNS Manager                 │
│                                              │
│  1. Start publishers                         │
│  2. Stop publishers                          │
│  3. Update / reload hosts                    │
│  4. Restart publishers                       │
│  5. Edit hosts                               │
│  6. View hosts                               │
│  7. View status                              │
│  8. Install boot persistence                 │
│  9. Remove boot persistence                  │
│  0. Exit                                     │
╰──────────────────────────────────────────────╯
```

---

## 🧩 How It Works

mDNS Manager uses **Avahi** to advertise hostnames on your local network.

Instead of configuring local DNS records on every device, you can define your hosts once:

```text
192.168.0.245 homepage.local
192.168.0.245 dockhand.local
192.168.0.245 immich.local
192.168.0.245 glance.local
```

Devices supporting mDNS can then resolve them directly:

```text
homepage.local
dockhand.local
immich.local
glance.local
```

No per-device DNS configuration is required.

---

## 📋 Requirements

* Linux
* systemd
* Bash
* Avahi

  * `avahi-daemon`
  * `avahi-publish`
* `sudo` access

### Verify Dependencies

Check that `avahi-publish` is available:

```bash
command -v avahi-publish
```

Check the Avahi daemon:

```bash
sudo systemctl status avahi-daemon
```

---

## 📦 Installation

Clone or copy the complete project directory to your server.

```bash
git clone https://github.com/krishna-o7/mDNS-by-Krishna.git
cd mDNS
sudo chmod +x mdns-manager.sh
```

The project should remain together:

```text
mDNS/
├── mdns-manager.sh
├── hosts
├── state/
├── runtime/
└── systemd/
```

The manager resolves its own directory at runtime, so the project can be moved or copied to another location without modifying the script.

---

## 🚀 Usage

Start the manager:

```bash
sudo ./mdns-manager.sh
```

You will be presented with the interactive menu.

---

## 🏠 Hosts Configuration

The `hosts` file defines the IP addresses and `.local` hostnames that should be published.

### Format

```text
IP_ADDRESS HOSTNAME
```

### Example

```text
192.168.0.245 homepage.local
192.168.0.245 dockhand.local
192.168.0.245 immich.local
192.168.0.245 glance.local
```

### Rules

* One host per line
* Blank lines are ignored
* Lines beginning with `#` are ignored
* Hostnames should use the `.local` domain

You can edit the file manually or use **option 5 — Edit hosts** from the manager.

---

## 🛠️ Menu Options

| Option | Action                   | Description                                                   |
| :----: | ------------------------ | ------------------------------------------------------------- |
|   `1`  | Start publishers         | Starts `avahi-publish` for every configured host              |
|   `2`  | Stop publishers          | Stops all running publishers                                  |
|   `3`  | Update / reload hosts    | Reloads the hosts file and restores the previous active state |
|   `4`  | Restart publishers       | Stops and starts all publishers                               |
|   `5`  | Edit hosts               | Opens the hosts file in an editor                             |
|   `6`  | View hosts               | Displays the current host configuration                       |
|   `7`  | View status              | Shows publisher, Avahi, and persistence status                |
|   `8`  | Install boot persistence | Installs the systemd service                                  |
|   `9`  | Remove boot persistence  | Disables and removes the systemd service                      |
|   `0`  | Exit                     | Closes the manager                                            |

---

## 🚀 Boot Persistence

mDNS Manager can optionally restore your publisher state automatically after a reboot.

When enabled, it creates:

```text
/etc/systemd/system/mdns-manager-publisher.service
```

The service uses:

```ini
RemainAfterExit=yes
```

This allows the manager to preserve whether publishers were active before shutdown.

### Behavior

| Before Reboot       | After Reboot                   |
| ------------------- | ------------------------------ |
| Publishers active   | Publishers start automatically |
| Publishers inactive | Publishers remain inactive     |

Install persistence from the TUI using:

```text
8. Install boot persistence
```

Remove it using:

```text
9. Remove boot persistence
```

---

## 🔄 Moving to Another Server

The entire project directory can be copied to another server.

For example:

```bash
scp -r mDNS user@server:/path/
```

Then on the new server:

```bash
cd /path/mDNS
sudo chmod +x mdns-manager.sh
sudo ./mdns-manager.sh
```

If required, install boot persistence again using **option 8**.

### Important

Do **not** manually copy the generated systemd service from:

```text
/etc/systemd/system/
```

The manager generates the service using the correct location of the project on the new server.

### The New Server Must Have

* Avahi installed and running
* `avahi-publish` available
* systemd
* sudo access
* Correct IP addresses in the `hosts` file

---

## 🔧 Troubleshooting

### Check Running Publishers

```bash
ps -eo pid,ppid,stat,cmd | grep '[a]vahi-publish'
```

### Check Saved State

```bash
cat state/publishers.state
```

Expected values:

```text
active
```

or:

```text
inactive
```

### Check Boot Persistence

```bash
sudo systemctl is-enabled mdns-manager-publisher.service
```

View the service:

```bash
sudo systemctl status mdns-manager-publisher.service --no-pager
```

### View Persistence Logs

```bash
sudo journalctl -u mdns-manager-publisher.service -b --no-pager
```

### Check Avahi

```bash
sudo systemctl status avahi-daemon --no-pager
```

---

## 💾 Backup

The project is self-contained, so backing up the complete directory is sufficient:

```bash
cp -a mDNS mDNS.backup
```

---

## 🔒 Safety

mDNS Manager only manages its own systemd service:

```text
mdns-manager-publisher.service
```

Removing boot persistence does **not** remove, disable, or modify other systemd services on the system.

---

## 📁 Project Structure

```text
mDNS/
├── mdns-manager.sh       # Main TUI manager
├── hosts                 # mDNS hostname configuration
├── state/                # Saved publisher state
├── runtime/              # Runtime publisher data
└── systemd/              # Project systemd-related files
```

---

## 📜 License

This project is licensed under the **MIT License**.

See [`LICENSE`](LICENSE) for details.
