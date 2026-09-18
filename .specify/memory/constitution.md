# DevOps Utilities Project Constitution

## Core Principles

### I. Script Architecture and Naming Conventions
- **One-off Administrative Utilities:** Standalone scripts focused on isolated operational tasks must use the `.sh` extension (e.g., `disk-health.sh`, `docker-cleanup.sh`, `threat-scan.sh`, `opencode-installer.sh`, `sys-update-checker.sh`).
- **Service & Lifecycle Managers:** Scripts responsible for end-to-end installation, configuration, persistence, and lifecycle management of services must follow the `service-<name>` convention without any file extension (e.g., `service-docker`, `service-evolution-api`).
- **Central Manager & Global CLI:**
  - The primary repository installer and manager is `install.sh`.
  - The globally accessible CLI command is the `inovatils` wrapper (installed to `/usr/local/bin/inovatils`).
  - Installed executables are centralized in `/usr/local/sbin/` with default permissions `750` (`chmod 750`).
  - Local versioning and installation states are tracked via the manifest at `~/.inova-devops/manifest`.

### II. Bash Standard & Execution Resilience
- **Shell Compatibility:** All scripts must begin with `#!/bin/bash` and implement automatic re-execution under Bash if inadvertently invoked via `sh`, `dash`, or `ash`.
- **Strict Mode:** Mandatory enforcement of `set -uo pipefail` to prevent uninitialized variables and masked pipeline failures.
- **Concurrency Control (Locking):** Maintenance and service scripts must employ exclusive directory locks (e.g., `/tmp/<name>.lock`) with guaranteed cleanup via `trap 'rmdir ...' EXIT`.
- **Principle of Least Privilege:** Execution must start in the caller's user context, elevating privileges via `sudo` exclusively for steps requiring root access (writing to `/usr/local/sbin`, `/etc`, system package managers, and `systemctl`).

### III. Installation Standards (`install`)
- **Pre-flight Environment Checks:**
  - Verification of supported Linux distributions (Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora, Arch Linux).
  - Minimum resource verification: available disk capacity, free RAM, and supported CPU architecture.
  - Package manager integrity (`apt`, `dnf`, `pacman`), system lock validation, and network reachability to official package repositories.
- **Intelligent State Detection:** Default execution without arguments must inspect system state: if the component is missing, it automatically initiates a clean installation; if already present, it reports status or transitions to the safe update workflow.
- **Safe Automation:** Mandatory support for `-y` / `--yes` (unattended execution using secure, hardened defaults) and `-c` / `--check-only` (dry-run diagnostics without modifying the host).
- **Security Hardening:** Cryptographically secure credential generation (passwords, API keys), restricted service users/groups, strict file permissions (`chmod 600` for `.env`), and isolated container networking.

### IV. Safe Update Standards (`update`)
- **Pre-Update State Snapshot:** Prior to applying any updates, scripts must generate a comprehensive plain-text runtime snapshot (.txt) under `/var/log/inova-devops/` capturing running containers, exposed ports, volumes, images, and disk utilization.
- **Mandatory Configuration Backup:** Full archive backup of configuration files (`.env`, `docker-compose.yml`, `daemon.json`) must be created prior to fetching or replacing binaries or container images.
- **Machine-Readable Rollback Manifest:** Generation of rollback manifests documenting previous versions, container IDs, and active project paths.
- **Automated and On-Demand Rollback (`--rollback`):**
  - Service scripts must provide a dedicated `--rollback` action to revert to the previous stable state on demand.
  - If post-update health checks fail, the script must alert the operator and offer immediate automated rollback.

### V. Destructive Uninstallation & Purge Standards (`uninstall`)
- **Critical Visual Alerts:** Prominent red warning banner itemizing every destructive consequence and data loss point prior to proceeding.
- **Mandatory User Password Authentication:** To prevent catastrophic execution in unattended shells or active sudo sessions, the invoking user's password must be explicitly re-authenticated (`sudo -k` followed by `sudo -v`), even if prior sudo credentials are cached.
- **Typed Confirmation Requirement:** Bypassing uninstallation prompts with `-y` is strictly forbidden. The operator must manually type the confirmation keyword `UNINSTALL` to authorize data deletion.
- **Complete System Purge:**
  - Immediate termination and removal of related containers, processes, and networks.
  - Disabling, removal, and daemon-reload of systemd service units.
  - Full package purge via the host distribution package manager.
  - Removal of added third-party repository lists and GPG keyrings.
  - Permanent deletion of persistent data directories (`/var/lib/...`), configuration paths (`/etc/...`, `/opt/...`), Docker volumes, and dedicated service user groups.

### VI. SDD & Development Artifact Hygiene
- **Separation of Concerns:** Specification-Driven Development (SDD) files—including the `.specify/` directory, `specs/` directory, and `AGENTS.md`—are development-only assets and must never be distributed, bundled, or retained in production runtime environments.
- **Runtime Cleanliness:** Both `install.sh` and `inovatils` must verify that development/SDD artifacts are excluded from state directories (`~/.inova-devops/`) and binary execution directories (`/usr/local/sbin/`, `/usr/local/bin/`). Any orphaned SDD residue found in runtime paths must be automatically cleaned up during installation and self-update routines.

## Standardized CLI Interface

All service and utility scripts must adhere to standard CLI actions and flags:

| Flag / Action | Purpose |
| :--- | :--- |
| *(no arguments)* | Interactive mode (guided wizard or intelligent state flow). |
| `-y`, `--yes` | Unattended automated mode with safe defaults. |
| `-c`, `--check-only` | Run pre-flight validations and checks without applying changes. |
| `--status` | Display runtime operational state, installed versions, and service health. |
| `--update` | Execute safe update routine with snapshots, backups, and verification. |
| `--rollback` | Downgrade and restore previous service state from backup. |
| `--uninstall` *(alias `--purge`)* | Complete destructive uninstallation with password authentication and typed confirmation. |
| `-h`, `--help` | Show command documentation, accepted options, and usage examples. |

## Observability & Logging

- All installation, update, and lifecycle execution logs must be stored in `/var/log/inova-devops/` with timestamps (e.g., `<service>-<YYYYMMDD-HHMMSS>.log`).
- If `/var/log` is not writable by the caller, scripts must automatically fall back to `${TMPDIR:-/tmp}/inova-devops/`.

## Governance

- This constitution establishes the non-negotiable architectural and quality principles for all scripts and utilities in the `devops-utilities` repository.
- Any modifications to execution patterns or new features must be formalized in this constitution before code implementation.

**Version**: 1.0.0 | **Ratified**: 2026-09-18 | **Last Amended**: 2026-09-18
