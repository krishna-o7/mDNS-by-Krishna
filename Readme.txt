# mDNS Manager

A simple terminal-based manager for publishing .local hostnames on your local network using Avahi.

## Screenshot

```
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

## Requirements

- Linux with systemd
- Bash
- Avahi (avahi-daemon and avahi-publish)
- sudo access

Verify your system has the required tools:

```bash
command -v avahi-publish
sudo systemctl status avahi-daemon
```

## Installation

Clone or copy the entire directory to your server:

```bash
git clone https://github.com/youruser/mDNS.git
cd mDNS
sudo chmod +x mdns-manager.sh
```

Keep the entire directory structure together:

```
mDNS/
├── mdns-manager.sh
├── hosts
├── state/
├── runtime/
└── systemd/
```

The script resolves its own directory at runtime, so the folder can be moved or copied to any location or server.

## Usage

```bash
sudo ./mdns-manager.sh
```

## Hosts File

The `hosts` file maps IP addresses to .local hostnames. Edit it manually or use option 5 from the menu.

Format:

```
IP_ADDRESS HOSTNAME
```

Example:

```
192.168.0.245 homepage.local
192.168.0.245 dockhand.local
192.168.0.245 immich.local
192.168.0.245 glance.local
```

Rules:

- One host per line
- Blank lines are ignored
- Lines starting with # are ignored

## Menu Options

| Option | Description |
|--------|-------------|
| 1 - Start publishers | Starts avahi-publish for each host in the hosts file |
| 2 - Stop publishers | Stops all running publishers |
| 3 - Update / reload hosts | Stops publishers, reloads hosts file, restarts if previously active |
| 4 - Restart publishers | Stops and starts all publishers |
| 5 - Edit hosts | Opens the hosts file in an editor |
| 6 - View hosts | Displays the current host configuration |
| 7 - View status | Shows publisher, avahi, and boot persistence status |
| 8 - Install boot persistence | Creates a systemd service that restores publishers on boot |
| 9 - Remove boot persistence | Disables and removes the systemd service |
| 0 - Exit | Closes the manager |

## Boot Persistence

When boot persistence is installed, the manager creates a systemd service at:

```
/etc/systemd/system/mdns-manager-publisher.service
```

The service uses `RemainAfterExit=yes` to restore the publisher state after reboot:

- If publishers were **active** before shutdown, they restart automatically
- If publishers were **inactive**, they stay inactive

## Moving to Another Server

Copy the entire directory:

```bash
scp -r mDNS user@server:/path/
```

On the new server:

```bash
cd /path/mDNS
sudo chmod +x mdns-manager.sh
sudo ./mdns-manager.sh
```

Then install boot persistence (option 8) if needed. Do not manually copy systemd service files from `/etc/systemd/system/` — the manager generates the correct service for the new location.

The new server must have:

- Avahi installed and running
- avahi-publish available
- systemd
- sudo access
- Correct IP addresses in the hosts file for the new network

## Troubleshooting

**Check running publishers:**

```bash
ps -eo pid,ppid,stat,cmd | grep '[a]vahi-publish'
```

**Check saved state:**

```bash
cat state/publishers.state
```

Expected output: `active` or `inactive`

**Check boot persistence:**

```bash
sudo systemctl is-enabled mdns-manager-publisher.service
sudo systemctl status mdns-manager-publisher.service --no-pager
```

**View persistence logs:**

```bash
sudo journalctl -u mdns-manager-publisher.service -b --no-pager
```

**Check Avahi daemon:**

```bash
sudo systemctl status avahi-daemon --no-pager
```

## Backup

Back up the complete directory:

```bash
cp -a mDNS mDNS.backup
```

## Safety

The manager only manages its own systemd service (`mdns-manager-publisher.service`). Removing boot persistence does not remove or disable any other systemd services.
