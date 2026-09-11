#!/usr/bin/env bash

set -u

# ============================================================
# mDNS Manager - by Krishna
# ============================================================

# Always use the directory containing this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

HOSTS_FILE="$SCRIPT_DIR/hosts"

RUNTIME_DIR="$SCRIPT_DIR/runtime"
STATE_DIR="$SCRIPT_DIR/state"
SYSTEMD_DIR="$SCRIPT_DIR/systemd"

PID_FILE="$RUNTIME_DIR/publisher.pids"
STATE_FILE="$STATE_DIR/publishers.state"
BOOT_STATE_FILE="$STATE_DIR/boot-persistence"

PUBLISHER="/usr/bin/avahi-publish"

SYSTEMD_NAME="mdns-manager-publisher.service"
SYSTEMD_FILE="$SYSTEMD_DIR/$SYSTEMD_NAME"
SYSTEMD_SYSTEM_FILE="/etc/systemd/system/$SYSTEMD_NAME"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------

mkdir -p "$RUNTIME_DIR"
mkdir -p "$STATE_DIR"
mkdir -p "$SYSTEMD_DIR"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

pause_screen() {
    echo
    read -rp " Press Enter to continue..."
}

get_pids() {
    [[ -f "$PID_FILE" ]] || return 0

    while read -r pid; do
        [[ -n "$pid" ]] || continue

        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
        fi
    done < "$PID_FILE"
}

publishers_active() {
    [[ -n "$(get_pids)" ]]
}

save_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "inactive"
    fi
}

boot_persistence_installed() {
    systemctl is-enabled --quiet "$SYSTEMD_NAME" 2>/dev/null
}

# ------------------------------------------------------------
# Hosts
# ------------------------------------------------------------

read_hosts() {
    [[ -f "$HOSTS_FILE" ]] || return 1

    while read -r ip hostname extra; do

        [[ -z "${ip:-}" ]] && continue
        [[ "${ip:0:1}" == "#" ]] && continue
        [[ -z "${hostname:-}" ]] && continue

        echo "$ip|$hostname"

    done < "$HOSTS_FILE"
}

count_hosts() {
    local count=0
    local ip
    local hostname

    while IFS='|' read -r ip hostname; do

        [[ -n "$ip" ]] || continue
        [[ -n "$hostname" ]] || continue

        count=$((count + 1))

    done < <(read_hosts)

    echo "$count"
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

start_publishers() {

    local existing
    local count=0
    local ip
    local hostname
    local pid

    existing="$(get_pids)"

    if [[ -n "$existing" ]]; then

        save_state "active"

        echo -e " ${YELLOW}● Publishers are already active.${RESET}"

        return 0
    fi

    if [[ ! -f "$HOSTS_FILE" ]]; then

        echo -e " ${RED}✖ Hosts file not found:${RESET}"
        echo "   $HOSTS_FILE"

        return 1
    fi

    if [[ ! -x "$PUBLISHER" ]]; then

        echo -e " ${RED}✖ avahi-publish was not found:${RESET}"
        echo "   $PUBLISHER"

        return 1
    fi

    rm -f "$PID_FILE"
    touch "$PID_FILE"

    while IFS='|' read -r ip hostname; do

        [[ -n "$ip" ]] || continue
        [[ -n "$hostname" ]] || continue

        "$PUBLISHER" -a -R "$hostname" "$ip" \
            >/dev/null 2>&1 &

        pid=$!

        echo "$pid" >> "$PID_FILE"

        echo -e " ${GREEN}✓${RESET} Started: $hostname → $ip"

        count=$((count + 1))

    done < <(read_hosts)

    if [[ "$count" -eq 0 ]]; then

        rm -f "$PID_FILE"
        save_state "inactive"

        echo -e " ${YELLOW}○ No valid hosts found.${RESET}"

        return 1
    fi

    save_state "active"

    echo
    echo -e " ${GREEN}✓ $count publisher(s) started.${RESET}"
}

# ------------------------------------------------------------
# Stop
# ------------------------------------------------------------

stop_publishers() {

    local pids
    local pid
    local stopped=0

    pids="$(get_pids)"

    if [[ -z "$pids" ]]; then

        rm -f "$PID_FILE"
        save_state "inactive"

        echo -e " ${YELLOW}○ Publishers are already inactive.${RESET}"

        return 0
    fi

    while read -r pid; do

        [[ -n "$pid" ]] || continue

        if kill -0 "$pid" 2>/dev/null; then

            kill "$pid" 2>/dev/null || true
            stopped=$((stopped + 1))

        fi

    done <<< "$pids"

    sleep 1

    rm -f "$PID_FILE"

    save_state "inactive"

    echo -e " ${GREEN}✓ Stopped $stopped publisher(s).${RESET}"
}

# ------------------------------------------------------------
# Update
# ------------------------------------------------------------

update_publishers() {

    local was_active="false"

    if publishers_active; then
        was_active="true"
    fi

    echo " Reloading hosts..."
    echo

    if [[ "$was_active" == "true" ]]; then

        echo " Stopping current publishers..."
        stop_publishers

        echo
        echo " Starting publishers using the updated hosts..."

        start_publishers

    else

        save_state "inactive"

        echo -e " ${GREEN}✓ Hosts reloaded.${RESET}"
        echo "   Publishers remain inactive."
    fi
}

# ------------------------------------------------------------
# Restart
# ------------------------------------------------------------

restart_publishers() {

    echo " Restarting publishers..."
    echo

    stop_publishers

    echo

    start_publishers
}

# ------------------------------------------------------------
# Edit hosts
# ------------------------------------------------------------

edit_hosts() {

    local before
    local after

    if [[ ! -f "$HOSTS_FILE" ]]; then

        echo -e " ${YELLOW}○ Hosts file does not exist.${RESET}"
        echo
        echo " Creating:"
        echo " $HOSTS_FILE"

        touch "$HOSTS_FILE"
    fi

    before="$(sha256sum "$HOSTS_FILE" 2>/dev/null || true)"

    echo
    echo " Opening hosts file..."
    echo

    sudo nano "$HOSTS_FILE"

    after="$(sha256sum "$HOSTS_FILE" 2>/dev/null || true)"

    echo

    if [[ "$before" == "$after" ]]; then

        echo -e " ${YELLOW}○ No changes were made.${RESET}"

        return 0
    fi

    echo -e " ${GREEN}✓ Hosts file updated.${RESET}"
    echo
    echo " Use 'Update / reload hosts' to apply the changes."
}

# ------------------------------------------------------------
# View hosts
# ------------------------------------------------------------

view_hosts() {

    clear

    echo "========================================"
    echo "             mDNS Hosts"
    echo "========================================"
    echo

    if [[ ! -f "$HOSTS_FILE" ]]; then

        echo -e "${RED}Hosts file not found.${RESET}"

        pause_screen
        return
    fi

    local ip
    local hostname
    local count=0

    while IFS='|' read -r ip hostname; do

        [[ -n "$ip" ]] || continue
        [[ -n "$hostname" ]] || continue

        printf "  %-20s → %s\n" "$hostname" "$ip"

        count=$((count + 1))

    done < <(read_hosts)

    if [[ "$count" -eq 0 ]]; then
        echo "  No hosts configured."
    fi

    echo
    echo "----------------------------------------"
    echo " Hosts: $count"

    pause_screen
}

# ------------------------------------------------------------
# View status
# ------------------------------------------------------------

view_status() {

    clear

    echo "========================================"
    echo "          mDNS Manager Status"
    echo "========================================"
    echo

    if publishers_active; then
        echo -e " Publisher          ${GREEN}● ACTIVE${RESET}"
    else
        echo -e " Publisher          ${YELLOW}● INACTIVE${RESET}"
    fi

    if systemctl is-active --quiet avahi-daemon.service; then
        echo -e " Avahi              ${GREEN}● RUNNING${RESET}"
    else
        echo -e " Avahi              ${RED}● STOPPED${RESET}"
    fi

    if boot_persistence_installed; then
        echo -e " Boot persistence   ${GREEN}● ENABLED${RESET}"
    else
        echo -e " Boot persistence   ${YELLOW}● DISABLED${RESET}"
    fi

    echo
    echo "----------------------------------------"
    echo

    echo " Configured hosts   $(count_hosts)"

    echo

    if [[ -f "$HOSTS_FILE" ]]; then

        local ip
        local hostname

        while IFS='|' read -r ip hostname; do

            [[ -n "$ip" ]] || continue
            [[ -n "$hostname" ]] || continue

            printf " %-18s → %s\n" "$hostname" "$ip"

        done < <(read_hosts)

    else

        echo " No hosts configured."

    fi

    echo
    echo "----------------------------------------"
    echo
    echo " Application directory:"
    echo " $SCRIPT_DIR"

    pause_screen
}

# ------------------------------------------------------------
# Install boot persistence
# ------------------------------------------------------------

install_boot_persistence() {

    echo
    echo " Installing boot persistence..."
    echo

    if [[ ! -x "$PUBLISHER" ]]; then

        echo -e " ${RED}✖ avahi-publish was not found.${RESET}"

        return 1
    fi

    cat > "$SYSTEMD_FILE" <<EOF
[Unit]
Description=mDNS Manager Publisher
After=avahi-daemon.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash "$SCRIPT_DIR/mdns-manager.sh" --boot-start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    install -m 0644 "$SYSTEMD_FILE" "$SYSTEMD_SYSTEM_FILE"

    systemctl daemon-reload
    systemctl enable "$SYSTEMD_NAME"

    echo "installed" > "$BOOT_STATE_FILE"

    echo
    echo -e " ${GREEN}✓ Boot persistence installed.${RESET}"
    echo
    echo " Current publisher state: $(get_state)"
    echo
    echo " The manager will restore the publisher state after reboot."
}

# ------------------------------------------------------------
# Remove boot persistence
# ------------------------------------------------------------

remove_boot_persistence() {

    echo
    echo " Removing boot persistence..."
    echo

    systemctl disable "$SYSTEMD_NAME" 2>/dev/null || true

    rm -f "$SYSTEMD_SYSTEM_FILE"
    rm -f "$SYSTEMD_FILE"
    rm -f "$BOOT_STATE_FILE"

    systemctl daemon-reload

    echo -e " ${GREEN}✓ Boot persistence removed.${RESET}"
    echo
    echo " No publishers were stopped."
    echo " No other systemd services were changed."
}

# ------------------------------------------------------------
# Boot startup
# ------------------------------------------------------------

boot_start() {

    if [[ "$(get_state)" != "active" ]]; then
        exit 0
    fi

    start_publishers
}

# ------------------------------------------------------------
# Main menu
# ------------------------------------------------------------

show_menu() {

    clear

    echo "========================================"
    echo "        mDNS Manager - by Krishna"
    echo "========================================"
    echo

    if publishers_active; then
        echo -e " Status : ${GREEN}● ACTIVE${RESET}"
    else
        echo -e " Status : ${YELLOW}● INACTIVE${RESET}"
    fi

    echo
    echo " mDNS Host Publisher Manager"
    echo
    echo "----------------------------------------"
    echo
    echo "  [1]  Start publishers"
    echo "  [2]  Stop publishers"
    echo "  [3]  Update / reload hosts"
    echo "  [4]  Restart publishers"
    echo "  [5]  Edit hosts"
    echo "  [6]  View hosts"
    echo "  [7]  View status"
    echo "  [8]  Install boot persistence"
    echo "  [9]  Remove boot persistence"
    echo
    echo "  [0]  Exit"
    echo
    echo "----------------------------------------"
}

# ------------------------------------------------------------
# Boot mode
# ------------------------------------------------------------

if [[ "${1:-}" == "--boot-start" ]]; then

    boot_start

    exit $?
fi

# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------

while true; do

    show_menu

    echo

    read -r -n 1 -p " Select an option [0-9]: " choice

    echo
    echo

    case "$choice" in

        1)
            start_publishers
            pause_screen
            ;;

        2)
            stop_publishers
            pause_screen
            ;;

        3)
            update_publishers
            pause_screen
            ;;

        4)
            restart_publishers
            pause_screen
            ;;

        5)
            edit_hosts
            pause_screen
            ;;

        6)
            view_hosts
            ;;

        7)
            view_status
            ;;

        8)
            install_boot_persistence
            pause_screen
            ;;

        9)
            remove_boot_persistence
            pause_screen
            ;;

        0)
            clear
            echo
            echo " mDNS Manager closed."
            echo
            exit 0
            ;;

        *)
            echo -e " ${RED}✖ Invalid option.${RESET}"
            pause_screen
            ;;

    esac

done
