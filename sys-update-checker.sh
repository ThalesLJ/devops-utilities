#!/bin/bash

# ==============================================================================
# System Update Checker & Production-Safe Updater
#
# Maintainer: Inova e-Business
# Version: 2.0
#
# Purpose:
#   Analyze system updates, run production-oriented preflight checks, preserve
#   package holds, apply updates with explicit confirmation, and validate the
#   system again after the update.
#
# Behavior:
#   - Without flags: analyze, preflight, confirm, update and post-validate.
#   - With -y / --yes: non-interactive update. Critical package updates require
#     --allow-critical.
#   - With -c / --check-only: refresh metadata and analyze only; no packages are
#     installed, removed or upgraded.
#   - Autoremove is never automatic. In interactive mode it is separately
#     simulated and confirmed; in --yes mode it is skipped.
#
# Optional health checks:
#   Set SYS_UPDATE_HEALTH_URLS to a space-separated list of URLs. If unset on
#   Linux, localhost HTTP/HTTPS endpoints are auto-detected from ports 80/443.
#
# Supported platforms:
#   - Linux   : apt / apt-get, dnf / yum
#   - macOS   : Homebrew and softwareupdate
#   - Windows : winget, chocolatey, scoop via compatible shells
# ==============================================================================

set -uo pipefail

VERSION="2.0"
TAG="sys-update"

ASSUME_YES=0
BULK_UPDATE=0
CHECK_ONLY=0
ALLOW_CRITICAL=0
SNAPSHOT_CONFIRMED=0
REBOOT_IF_REQUIRED=0
UPDATE_FAILED=0
POSTCHECK_FAILED=0

log()  { printf '%s\n' "$*"; }
info() { printf '  \033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '  \033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '  \033[1;31m[ERR]\033[0m  %s\n' "$*"; }

TTY=0
[ -t 1 ] && TTY=1
SPIN_FRAMES=('|' '/' '-' '\\')
if [[ "$(locale charmap 2>/dev/null)" == *"UTF"* ]]; then
    SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
fi

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
START_TS="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)"
LOG_DIR="/var/log/inova-devops"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    LOG_DIR="${TMPDIR:-/tmp}/inova-devops"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
fi
LOG_FILE="${LOG_DIR}/sys-update-${START_TS}.log"
if touch "$LOG_FILE" 2>/dev/null; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

_spin() {
    local pid="$1" label="$2" i=0 n=${#SPIN_FRAMES[@]}
    [ "$TTY" = 1 ] || return 0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r  \033[1;36m%s\033[0m %s   ' "${SPIN_FRAMES[$i]}" "$label" > /dev/tty 2>/dev/null || true
        i=$(( (i + 1) % n ))
        sleep 0.08
    done
    printf '\r\033[K' > /dev/tty 2>/dev/null || true
}

# Run a command while preserving its real exit code and complete output.
run_spinner() {
    local label="$1"; shift
    local tmp rc
    tmp="$(mktemp)" || return 1

    if [ "$TTY" = 1 ]; then
        "$@" >"$tmp" 2>&1 &
        local pid=$!
        _spin "$pid" "$label"
        wait "$pid"
        rc=$?
    else
        "$@" >"$tmp" 2>&1
        rc=$?
    fi

    cat "$tmp"
    rm -f "$tmp"
    return "$rc"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -y, --yes               Apply updates without normal confirmation prompts.
  -c, --check-only        Analyze only; do not install/remove/upgrade packages.
      --allow-critical    Allow critical package updates in --yes mode.
      --snapshot-confirmed
                          Confirm that an external snapshot/backup exists.
      --reboot-if-required
                          In --yes mode, reboot after successful validation if required.
  -h, --help              Show this help.

Environment:
  SYS_UPDATE_HEALTH_URLS  Space-separated URLs to test before and after update.

Examples:
  $0
  $0 --check-only
  $0 --yes --snapshot-confirmed
  $0 --yes --snapshot-confirmed --allow-critical
  $0 --yes --snapshot-confirmed --allow-critical --reboot-if-required
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes)              ASSUME_YES=1 ;;
        -c|--check-only)       CHECK_ONLY=1 ;;
        --allow-critical)      ALLOW_CRITICAL=1 ;;
        --snapshot-confirmed)  SNAPSHOT_CONFIRMED=1 ;;
        --reboot-if-required)  REBOOT_IF_REQUIRED=1 ;;
        -h|--help)             usage; exit 0 ;;
        *) err "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# -----------------------------------------------------------------------------
# Platform / package manager detection
# -----------------------------------------------------------------------------
OS_TYPE="$(uname -s 2>/dev/null || echo unknown)"
case "$OS_TYPE" in
    Darwin) OS_NAME="macOS" ;;
    MINGW*|MSYS*|CYGWIN*) OS_NAME="Windows" ;;
    Linux) OS_NAME="Linux" ;;
    *) OS_NAME="$OS_TYPE" ;;
esac

PKG_MANAGER=""
detect_package_manager() {
    case "$OS_TYPE" in
        Darwin)
            command -v brew >/dev/null 2>&1 || { err "Homebrew not found."; return 1; }
            PKG_MANAGER="brew"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            if command -v winget >/dev/null 2>&1; then PKG_MANAGER="winget"
            elif command -v choco >/dev/null 2>&1; then PKG_MANAGER="choco"
            elif command -v scoop >/dev/null 2>&1; then PKG_MANAGER="scoop"
            else err "No supported Windows package manager found."; return 1
            fi
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt"
            elif command -v dnf >/dev/null 2>&1; then PKG_MANAGER="dnf"
            elif command -v yum >/dev/null 2>&1; then PKG_MANAGER="yum"
            else err "No supported Linux package manager found."; return 1
            fi
            ;;
        *) err "Unsupported platform: $OS_TYPE"; return 1 ;;
    esac
    return 0
}

detect_package_manager || exit 1

ask() {
    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi
    local answer
    printf '  \033[1;36m[?]\033[0m %s [y/N] ' "$1" > /dev/tty
    if [ -r /dev/tty ]; then read -r answer < /dev/tty; else read -r answer; fi
    case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# -----------------------------------------------------------------------------
# System information
# -----------------------------------------------------------------------------
OS_PRETTY="$(uname -srm 2>/dev/null || echo n/a)"
HOSTNAME="$(hostname 2>/dev/null || uname -n)"
KERNEL_RUNNING="$(uname -r 2>/dev/null || echo n/a)"
UPTIME="$(uptime 2>/dev/null | sed 's/^ *//' || echo n/a)"

printf '\n'
printf '  %s\n' '============================================================'
printf '  %s\n' '  SYSTEM UPDATE CHECKER - PRODUCTION SAFE MODE'
printf '  %s\n' '  Maintainer: Inova e-Business'
printf '  %s\n' "  Version: $VERSION"
printf '  %s\n' '============================================================'
printf '\n'
log "  Platform        : $OS_NAME ($OS_PRETTY)"
log "  Hostname        : $HOSTNAME"
log "  Package manager : $PKG_MANAGER"
log "  Running kernel  : $KERNEL_RUNNING"
log "  Uptime          : $UPTIME"
log "  Log             : $LOG_FILE"
printf '\n'

# -----------------------------------------------------------------------------
# Production preflight helpers (Linux)
# -----------------------------------------------------------------------------
BASELINE_RUNNING_SERVICES=""
BASELINE_FAILED_SERVICES=""
HEALTH_URLS=""
HEALTH_BASELINE_FILE="$(mktemp)"
STATE_DIR=""

cleanup() {
    rm -f "$HEALTH_BASELINE_FILE" 2>/dev/null || true
}
trap cleanup EXIT

service_is_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

capture_service_baseline() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    command -v systemctl >/dev/null 2>&1 || return 0
    BASELINE_RUNNING_SERVICES="$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sort -u)"
    BASELINE_FAILED_SERVICES="$(systemctl --failed --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sort -u)"
}

check_disk_space() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    local avail_kb
    avail_kb="$(df -Pk / 2>/dev/null | awk 'NR==2 {print $4}')"
    if [ -n "$avail_kb" ] && [ "$avail_kb" -lt 1048576 ]; then
        err "Less than 1 GiB free on /. Aborting update."
        return 1
    fi
    if [ -n "$avail_kb" ] && [ "$avail_kb" -lt 2097152 ]; then
        warn "Less than 2 GiB free on /. Proceed with caution."
    else
        ok "Root filesystem has sufficient free space."
    fi
    return 0
}

validate_active_webservers() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    local rc=0

    if service_is_active apache2 || service_is_active httpd; then
        info "Validating Apache configuration..."
        if command -v apachectl >/dev/null 2>&1; then
            apachectl configtest || rc=1
        elif command -v apache2ctl >/dev/null 2>&1; then
            apache2ctl configtest || rc=1
        fi
    fi

    if service_is_active nginx; then
        info "Validating Nginx configuration..."
        nginx -t || rc=1
    fi

    if service_is_active lsws || service_is_active openlitespeed || service_is_active lshttpd; then
        info "Validating OpenLiteSpeed configuration..."
        if [ -x /usr/local/lsws/bin/openlitespeed ]; then
            /usr/local/lsws/bin/openlitespeed -t || rc=1
        else
            warn "OpenLiteSpeed is active but its configuration test binary was not found."
            rc=1
        fi
    fi

    if [ "$rc" -ne 0 ]; then
        err "Active web server configuration validation failed. Aborting update."
        return 1
    fi
    return 0
}

validate_package_state() {
    [ "$PKG_MANAGER" = "apt" ] || return 0

    info "Checking APT/dpkg consistency..."
    if ! apt-get check; then
        err "apt-get check failed. Fix package dependencies before updating."
        return 1
    fi

    local audit
    audit="$(dpkg --audit 2>&1 || true)"
    if [ -n "$audit" ]; then
        err "dpkg reports incomplete/broken package state:"
        printf '%s\n' "$audit" | sed 's/^/    /'
        return 1
    fi
    ok "APT/dpkg state is consistent."
    return 0
}

detect_health_urls() {
    if [ -n "${SYS_UPDATE_HEALTH_URLS:-}" ]; then
        HEALTH_URLS="$SYS_UPDATE_HEALTH_URLS"
        return 0
    fi

    [ "$OS_TYPE" = "Linux" ] || return 0
    command -v ss >/dev/null 2>&1 || return 0

    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)(80)$'; then
        HEALTH_URLS="http://127.0.0.1/"
    elif ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)(443)$'; then
        HEALTH_URLS="https://127.0.0.1/"
    fi
}

health_probe() {
    local url="$1" result
    if ! command -v curl >/dev/null 2>&1; then
        printf 'NO_CURL'
        return 0
    fi
    result="$(curl -k -sS -o /dev/null --max-time 10 -w '%{http_code}' "$url" 2>/dev/null)" || result="000"
    printf '%s' "$result"
}

capture_health_baseline() {
    : > "$HEALTH_BASELINE_FILE"
    detect_health_urls
    [ -n "$HEALTH_URLS" ] || { info "No HTTP health endpoint auto-detected."; return 0; }

    info "Running pre-update health checks..."
    local url status
    for url in $HEALTH_URLS; do
        status="$(health_probe "$url")"
        printf '%s\t%s\n' "$url" "$status" >> "$HEALTH_BASELINE_FILE"
        if [ "$status" = "000" ] || [ "$status" = "NO_CURL" ]; then
            err "Health check failed before update: $url ($status)"
            return 1
        fi
        ok "$url -> HTTP $status"
    done
    return 0
}

save_preupdate_state() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    STATE_DIR="/var/log/inova-devops/pre-update-${START_TS}"
    mkdir -p "$STATE_DIR" 2>/dev/null || STATE_DIR="${TMPDIR:-/tmp}/pre-update-${START_TS}"
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0

    dpkg --get-selections > "$STATE_DIR/dpkg-selections.txt" 2>/dev/null || true
    apt-mark showhold > "$STATE_DIR/apt-holds.txt" 2>/dev/null || true
    systemctl list-units --type=service --all --no-pager > "$STATE_DIR/systemd-services.txt" 2>/dev/null || true
    ss -ltnp > "$STATE_DIR/listening-ports.txt" 2>/dev/null || true
    if [ -d /etc/apt ]; then cp -a /etc/apt "$STATE_DIR/apt-config" 2>/dev/null || true; fi
    if [ -d /etc/apache2 ]; then cp -a /etc/apache2 "$STATE_DIR/apache2-config" 2>/dev/null || true; fi
    if [ -d /etc/nginx ]; then cp -a /etc/nginx "$STATE_DIR/nginx-config" 2>/dev/null || true; fi
    if [ -d /usr/local/lsws/conf ]; then cp -a /usr/local/lsws/conf "$STATE_DIR/openlitespeed-config" 2>/dev/null || true; fi
    if [ -d /etc/docker ]; then cp -a /etc/docker "$STATE_DIR/docker-config" 2>/dev/null || true; fi
    if [ -d /etc/systemd/system ]; then cp -a /etc/systemd/system "$STATE_DIR/systemd-config" 2>/dev/null || true; fi
    info "Pre-update state saved to $STATE_DIR"
}

run_linux_preflight() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    info "Running production preflight checks..."
    check_disk_space || return 1
    validate_package_state || return 1
    validate_active_webservers || return 1

    if service_is_active docker && command -v docker >/dev/null 2>&1; then
        info "Validating Docker daemon..."
        docker info >/dev/null 2>&1 || { err "Docker service is active but docker info failed."; return 1; }
        ok "Docker daemon is responding."
    fi

    capture_service_baseline
    capture_health_baseline || return 1
    save_preupdate_state
    return 0
}

# -----------------------------------------------------------------------------
# Update metadata and simulation
# -----------------------------------------------------------------------------
UPGRADABLE_COUNT=0
SECURITY_COUNT=0
UPGRADABLE_LIST=""
HELD_PACKAGES=""
SIMULATION_OUTPUT=""
CRITICAL_UPDATES=""
MACOS_SYS_UPDATES=""
ELIGIBLE_PACKAGES=""
ELIGIBLE_COUNT=0

strict_apt_update() {
    local tmp rc
    tmp="$(mktemp)" || return 1
    info "Refreshing APT package metadata..."
    apt-get update >"$tmp" 2>&1
    rc=$?
    cat "$tmp"

    if [ "$rc" -ne 0 ] || grep -Eq '^(Err:|W: Failed to fetch|W: Some index files failed|W: An error occurred during|W: GPG error:|W: The repository .* is not signed)' "$tmp"; then
        err "APT metadata refresh was incomplete or failed. No packages will be upgraded."
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    ok "APT metadata refreshed successfully."
    return 0
}

collect_updates() {
    case "$PKG_MANAGER" in
        apt)
            strict_apt_update || return 1
            HELD_PACKAGES="$(apt-mark showhold 2>/dev/null || true)"
            UPGRADABLE_LIST="$(apt list --upgradable 2>/dev/null | grep 'upgradable' || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c 'upgradable' || true)"

            SIMULATION_OUTPUT="$(apt-get -s upgrade 2>&1)" || {
                err "APT upgrade simulation failed:"
                printf '%s\n' "$SIMULATION_OUTPUT"
                return 1
            }
            ELIGIBLE_PACKAGES="$(printf '%s\n' "$SIMULATION_OUTPUT" | awk '/^Inst / {print $2}' | sort -u)"
            ELIGIBLE_COUNT="$(printf '%s\n' "$ELIGIBLE_PACKAGES" | grep -c . || true)"
            SECURITY_COUNT="$(printf '%s\n' "$SIMULATION_OUTPUT" | grep -c '^Inst.*[Ss]ecurity' || true)"
            CRITICAL_UPDATES="$(printf '%s\n' "$SIMULATION_OUTPUT" | grep -Ei '^Inst (linux-|libc6|libssl|openssl|systemd|openssh-server|network-manager|libnm|docker-ce|docker.io|containerd|apache2|nginx|openlitespeed|lsws|mongodb|mysql|mariadb|postgresql|php[0-9.]|dotnet-|aspnetcore-|monarx)' || true)"
            ;;
        dnf|yum)
            UPGRADABLE_LIST="$($PKG_MANAGER -q check-update 2>/dev/null | grep '\.' || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c '\.' || true)"
            SECURITY_COUNT="$($PKG_MANAGER -q updateinfo list security 2>/dev/null | grep -c '\.' || true)"
            ;;
        brew)
            run_spinner "Updating Homebrew metadata ..." brew update || return 1
            UPGRADABLE_LIST="$(brew outdated 2>/dev/null || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c . || true)"
            ;;
        winget)
            UPGRADABLE_LIST="$(winget upgrade 2>/dev/null | tail -n +3 || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c . || true)"
            ;;
        choco)
            UPGRADABLE_LIST="$(choco outdated 2>/dev/null | tail -n +2 || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c '|' || true)"
            ;;
        scoop)
            run_spinner "Checking Scoop ..." scoop update || return 1
            UPGRADABLE_LIST="$(scoop status 2>/dev/null || true)"
            UPGRADABLE_COUNT="$(printf '%s\n' "$UPGRADABLE_LIST" | grep -c '^[a-zA-Z]' || true)"
            ;;
    esac
    return 0
}

collect_updates || exit 1

if [ "$PKG_MANAGER" = "brew" ] && command -v softwareupdate >/dev/null 2>&1; then
    MACOS_SYS_UPDATES="$(softwareupdate -l 2>/dev/null | grep -E '^\s*\*' || true)"
fi

# -----------------------------------------------------------------------------
# Reboot / restart detection (call before and after update)
# -----------------------------------------------------------------------------
REBOOT_REQUIRED=0
SERVICES_NEED_RESTART=""
detect_restart_state() {
    REBOOT_REQUIRED=0
    SERVICES_NEED_RESTART=""

    if [ -f /var/run/reboot-required ]; then
        REBOOT_REQUIRED=1
    elif command -v needs-restarting >/dev/null 2>&1; then
        needs-restarting -r >/dev/null 2>&1
        case $? in
            1) REBOOT_REQUIRED=1 ;;
        esac
    fi

    if command -v needs-restarting >/dev/null 2>&1; then
        SERVICES_NEED_RESTART="$(needs-restarting -s 2>/dev/null || true)"
    elif [ -f /var/run/reboot-required.pkgs ]; then
        SERVICES_NEED_RESTART="$(cat /var/run/reboot-required.pkgs 2>/dev/null || true)"
    fi
}

detect_restart_state

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
if [ "$PKG_MANAGER" = "apt" ]; then TOTAL_PENDING="$ELIGIBLE_COUNT"; else TOTAL_PENDING="$UPGRADABLE_COUNT"; fi
if [ -n "$MACOS_SYS_UPDATES" ]; then
    MACOS_SYS_COUNT="$(printf '%s\n' "$MACOS_SYS_UPDATES" | grep -c . || true)"
    TOTAL_PENDING=$(( TOTAL_PENDING + MACOS_SYS_COUNT ))
fi

printf '\n'
printf '  %s\n' '------------------------------------------------------------'
printf '  %s\n' '  SUMMARY'
printf '  %s\n' '------------------------------------------------------------'
printf '\n'

if [ "$TOTAL_PENDING" -gt 0 ]; then
    warn "$TOTAL_PENDING resource(s) eligible for update."
    [ "$SECURITY_COUNT" -gt 0 ] && warn "$SECURITY_COUNT update(s) appear security-related."
    printf '\n'
    if [ "$UPGRADABLE_COUNT" -gt 0 ]; then
        info "Packages with updates available:"
        printf '%s\n' "$UPGRADABLE_LIST" | sed 's/^/    /'
    fi
else
    ok "All packages are up to date."
fi

if [ "$PKG_MANAGER" = "apt" ]; then
    printf '\n'
    if [ -n "$HELD_PACKAGES" ]; then
        info "APT held packages (will remain protected):"
        printf '%s\n' "$HELD_PACKAGES" | sed 's/^/    /'
    else
        info "APT held packages: none"
    fi

    printf '\n'
    info "APT upgrade simulation:"
    printf '%s\n' "$SIMULATION_OUTPUT" | sed 's/^/    /'

    if [ -n "$CRITICAL_UPDATES" ]; then
        printf '\n'
        warn "Potentially critical packages are included in the simulation:"
        printf '%s\n' "$CRITICAL_UPDATES" | sed 's/^/    /'
    fi
fi

printf '\n'
if [ "$REBOOT_REQUIRED" -eq 1 ]; then
    warn "System already indicates a reboot is required."
else
    ok "No reboot requirement currently detected."
fi

printf '\n'
printf '  %s\n' '------------------------------------------------------------'

if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '\n'
    ok "Check-only mode. Package metadata may have been refreshed; no packages were installed, removed or upgraded."
    exit 0
fi

if [ "$TOTAL_PENDING" -eq 0 ]; then
    printf '\n'
    ok "Nothing to update. Exiting."
    exit 0
fi

# Root is required for package mutation on Linux.
if [ "$OS_TYPE" = "Linux" ] && [ "$(id -u)" -ne 0 ]; then
    err "Run as root to apply system updates."
    exit 1
fi

run_linux_preflight || exit 1

# Snapshot/backup confirmation for interactive production updates.
if [ "$OS_TYPE" = "Linux" ] && [ "$SNAPSHOT_CONFIRMED" -eq 0 ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        err "Refusing unattended production update without --snapshot-confirmed."
        exit 1
    else
        if ask "Do you have a current external snapshot/backup and rollback path?"; then
            SNAPSHOT_CONFIRMED=1
        else
            err "Update cancelled. Create/verify a snapshot or backup first."
            exit 1
        fi
    fi
fi

# Critical update gate.
if [ "$PKG_MANAGER" = "apt" ] && [ -n "$CRITICAL_UPDATES" ]; then
    if [ "$ASSUME_YES" -eq 1 ] && [ "$ALLOW_CRITICAL" -ne 1 ]; then
        err "Critical package updates detected. Refusing unattended update without --allow-critical."
        exit 1
    fi
    if [ "$ASSUME_YES" -eq 0 ]; then
        if ! ask "Critical packages are included. Proceed with these updates?"; then
            err "Update cancelled because critical packages were not approved."
            exit 1
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Acceptance
# -----------------------------------------------------------------------------
printf '\n'
if [ "$ASSUME_YES" -eq 1 ]; then
    BULK_UPDATE=1
    info "Running in --yes mode. Applying approved updates..."
else
    if ! ask "Proceed with the update?"; then
        warn "Update cancelled by user."
        exit 0
    fi
    if ask "Update all eligible packages at once?"; then
        BULK_UPDATE=1
        info "Will update all eligible packages in one transaction."
    else
        info "Will confirm each package individually."
    fi
fi

is_held_package() {
    local pkg="$1"
    printf '%s\n' "$HELD_PACKAGES" | grep -Fxq "$pkg"
}

apt_upgrade_all() {
    info "Applying APT upgrade..."
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold upgrade
}

apt_upgrade_one() {
    local pkg="$1"
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold install --only-upgrade "$pkg"
}

apply_updates() {
    case "$PKG_MANAGER" in
        apt)
            if [ "$BULK_UPDATE" -eq 1 ]; then
                if ! run_spinner "Upgrading packages ..." apt_upgrade_all; then
                    err "APT upgrade failed. See $LOG_FILE"
                    return 1
                fi
            else
                local pkg failures=0
                while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    if is_held_package "$pkg"; then
                        info "Skipping held package '$pkg'."
                        continue
                    fi
                    if ask "Update package '$pkg'?"; then
                        if ! run_spinner "Updating $pkg ..." apt_upgrade_one "$pkg"; then
                            err "Failed to update $pkg"
                            failures=$((failures + 1))
                        fi
                    else
                        info "Skipped $pkg"
                    fi
                done <<< "$ELIGIBLE_PACKAGES"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
        dnf|yum)
            if [ "$BULK_UPDATE" -eq 1 ]; then
                run_spinner "Upgrading packages ..." "$PKG_MANAGER" -y upgrade || return 1
            else
                local line pkg failures=0
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    pkg="$(printf '%s\n' "$line" | awk '{print $1}' | sed 's/\..*//')"
                    [ -z "$pkg" ] && continue
                    if ask "Update package '$pkg'?"; then
                        run_spinner "Updating $pkg ..." "$PKG_MANAGER" -y upgrade "$pkg" || failures=$((failures + 1))
                    else info "Skipped $pkg"; fi
                done <<< "$UPGRADABLE_LIST"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
        brew)
            if [ "$BULK_UPDATE" -eq 1 ]; then run_spinner "Upgrading Homebrew packages ..." brew upgrade || return 1
            else
                local line pkg failures=0
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    pkg="$(printf '%s\n' "$line" | awk '{print $1}')"
                    [ -z "$pkg" ] && continue
                    if ask "Update package '$pkg'?"; then run_spinner "Updating $pkg ..." brew upgrade "$pkg" || failures=$((failures + 1)); else info "Skipped $pkg"; fi
                done <<< "$UPGRADABLE_LIST"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
        winget)
            if [ "$BULK_UPDATE" -eq 1 ]; then run_spinner "Upgrading packages ..." winget upgrade --all || return 1
            else
                local line pkg failures=0
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    pkg="$(printf '%s\n' "$line" | awk '{print $2}')"
                    [ -z "$pkg" ] && continue
                    if ask "Update package '$pkg'?"; then run_spinner "Updating $pkg ..." winget upgrade --id "$pkg" || failures=$((failures + 1)); else info "Skipped $pkg"; fi
                done <<< "$UPGRADABLE_LIST"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
        choco)
            if [ "$BULK_UPDATE" -eq 1 ]; then run_spinner "Upgrading packages ..." choco upgrade all -y || return 1
            else
                local line pkg failures=0
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    pkg="$(printf '%s\n' "$line" | awk -F'|' '{print $1}')"
                    [ -z "$pkg" ] && continue
                    if ask "Update package '$pkg'?"; then run_spinner "Updating $pkg ..." choco upgrade "$pkg" -y || failures=$((failures + 1)); else info "Skipped $pkg"; fi
                done <<< "$UPGRADABLE_LIST"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
        scoop)
            if [ "$BULK_UPDATE" -eq 1 ]; then run_spinner "Upgrading packages ..." scoop update '*' || return 1
            else
                local line pkg failures=0
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    pkg="$(printf '%s\n' "$line" | awk '{print $1}')"
                    [ -z "$pkg" ] && continue
                    if ask "Update package '$pkg'?"; then run_spinner "Updating $pkg ..." scoop update "$pkg" || failures=$((failures + 1)); else info "Skipped $pkg"; fi
                done <<< "$UPGRADABLE_LIST"
                [ "$failures" -eq 0 ] || return 1
            fi
            ;;
    esac
    return 0
}

if ! apply_updates; then
    UPDATE_FAILED=1
    err "Update transaction reported a failure. Automatic cleanup/removal will not run."
fi

# macOS system updates only if package update succeeded.
if [ "$UPDATE_FAILED" -eq 0 ] && [ -n "$MACOS_SYS_UPDATES" ]; then
    printf '\n'
    if [ "$ASSUME_YES" -eq 1 ]; then
        softwareupdate -i -a || UPDATE_FAILED=1
    elif ask "Apply macOS system updates?"; then
        softwareupdate -i -a || UPDATE_FAILED=1
    else
        info "Skipped macOS system updates."
    fi
fi

# -----------------------------------------------------------------------------
# Autoremove is deliberately separate and never automatic in --yes mode.
# -----------------------------------------------------------------------------
if [ "$UPDATE_FAILED" -eq 0 ] && [ "$PKG_MANAGER" = "apt" ]; then
    AUTOREMOVE_SIM="$(apt-get -s autoremove 2>&1 || true)"
    if printf '%s\n' "$AUTOREMOVE_SIM" | grep -q '^Remv '; then
        printf '\n'
        warn "APT reports packages eligible for autoremove:"
        printf '%s\n' "$AUTOREMOVE_SIM" | grep '^Remv ' | sed 's/^/    /'
        if [ "$ASSUME_YES" -eq 1 ]; then
            warn "Autoremove skipped in --yes mode by safety policy."
        elif ask "Run apt-get autoremove now?"; then
            run_spinner "Removing explicitly approved unused packages ..." apt-get -y autoremove || warn "Autoremove failed; review manually."
        else
            info "Autoremove skipped."
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Post-update validation
# -----------------------------------------------------------------------------
validate_post_update() {
    [ "$OS_TYPE" = "Linux" ] || return 0
    local failed=0 svc url before after audit current_failed

    info "Running post-update validation..."

    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get check || { err "APT dependency check failed after update."; failed=1; }
        audit="$(dpkg --audit 2>&1 || true)"
        if [ -n "$audit" ]; then
            err "dpkg reports incomplete package state after update:"
            printf '%s\n' "$audit" | sed 's/^/    /'
            failed=1
        fi
    fi

    while IFS= read -r svc; do
        [ -z "$svc" ] && continue
        if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
            err "Previously running service is no longer active: $svc"
            failed=1
        fi
    done <<< "$BASELINE_RUNNING_SERVICES"

    current_failed="$(systemctl --failed --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sort -u)"
    while IFS= read -r svc; do
        [ -z "$svc" ] && continue
        if ! printf '%s\n' "$BASELINE_FAILED_SERVICES" | grep -Fxq "$svc"; then
            err "New failed systemd service detected: $svc"
            failed=1
        fi
    done <<< "$current_failed"

    validate_active_webservers || failed=1

    if service_is_active docker && command -v docker >/dev/null 2>&1; then
        docker info >/dev/null 2>&1 || { err "Docker is not responding after update."; failed=1; }
    fi

    if [ -s "$HEALTH_BASELINE_FILE" ]; then
        while IFS=$'\t' read -r url before; do
            [ -z "$url" ] && continue
            after="$(health_probe "$url")"
            if [ "$after" = "000" ] || [ "$after" = "NO_CURL" ]; then
                err "Health check failed after update: $url (before=$before after=$after)"
                failed=1
            else
                ok "$url -> HTTP $after (before $before)"
                [ "$before" = "$after" ] || warn "HTTP status changed for $url: $before -> $after"
            fi
        done < "$HEALTH_BASELINE_FILE"
    fi

    if [ "$failed" -ne 0 ]; then
        return 1
    fi
    ok "Post-update validation passed."
    return 0
}

if [ "$UPDATE_FAILED" -eq 0 ]; then
    validate_post_update || POSTCHECK_FAILED=1
else
    POSTCHECK_FAILED=1
fi

# Recalculate restart/reboot requirements AFTER package changes.
detect_restart_state

printf '\n'
printf '  %s\n' '------------------------------------------------------------'
printf '  %s\n' '  FINAL STATUS'
printf '  %s\n' '------------------------------------------------------------'

if [ "$UPDATE_FAILED" -ne 0 ]; then
    err "Update did not complete successfully. Review $LOG_FILE"
elif [ "$POSTCHECK_FAILED" -ne 0 ]; then
    err "Packages updated, but post-update validation FAILED. Review services immediately."
    [ -n "$STATE_DIR" ] && warn "Pre-update state: $STATE_DIR"
else
    ok "Update completed and post-update validation passed."
fi

if [ -n "$SERVICES_NEED_RESTART" ]; then
    printf '\n'
    warn "Packages/services may still require restart:"
    printf '%s\n' "$SERVICES_NEED_RESTART" | sed 's/^/    /'
fi

if [ "$REBOOT_REQUIRED" -eq 1 ]; then
    printf '\n'
    warn "A reboot is required/recommended after this update."
    if [ "$POSTCHECK_FAILED" -ne 0 ]; then
        info "Reboot postponed because post-update validation did not pass."
    elif [ "$ASSUME_YES" -eq 1 ]; then
        if [ "$REBOOT_IF_REQUIRED" -eq 1 ]; then
            warn "Rebooting now because --reboot-if-required was explicitly provided..."
            reboot
        else
            info "Reboot postponed. Use --reboot-if-required for explicit unattended reboot."
        fi
    elif ask "Reboot the system now?"; then
        warn "Rebooting now..."
        reboot
    else
        info "Reboot postponed."
    fi
else
    printf '\n'
    ok "No reboot requirement detected after update."
fi

printf '\n'
log "System update checker completed. Log: $LOG_FILE"

if [ "$UPDATE_FAILED" -ne 0 ]; then exit 1; fi
if [ "$POSTCHECK_FAILED" -ne 0 ]; then exit 2; fi
exit 0
