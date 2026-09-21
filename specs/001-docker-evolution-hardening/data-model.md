# Data Model & Configuration Schemas: Docker & Evolution API Hardening

**Feature**: [spec.md](./spec.md)  
**Date**: 2026-09-21

---

## 1. Entities & Configuration Models

### Entity: Host Service User
Represents unprivileged system accounts created to isolate service runtime and file ownership from root.

| Field | Type | Required | Default Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `username` | string | Yes | `docker-user` / `evolution-user` | System account name |
| `system_account` | boolean | Yes | `true` (`-r`) | Non-human system user |
| `shell` | string | Yes | `/usr/sbin/nologin` | Disabled interactive shell |
| `home_dir` | string | Yes | `/opt/evolution-api` (for evolution-user) | Target working directory |
| `groups` | array | Yes | `["docker"]` | Supplementary group for socket access |

---

### Entity: Docker Daemon Configuration (`/etc/docker/daemon.json`)
Represents the host Docker engine runtime configuration.

```json
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "3"
  },
  "userland-proxy": false
}
```

| Property | Type | Description |
| :--- | :--- | :--- |
| `live-restore` | boolean | Keeps containers active during Docker daemon updates or restarts |
| `log-driver` | string | Standard JSON file logging |
| `log-opts.max-size` | string | Maximum file size before rotation (20 MB) |
| `log-opts.max-file` | string | Maximum number of rotated log files to retain (3 files) |
| `userland-proxy` | boolean | Disables userland proxy in favor of native kernel iptables |

---

### Entity: Stack Resource Allocation Model (`/opt/evolution-api/.env`)
Represents container memory and CPU bounds configured to support ~10 WhatsApp instances.

```env
# ==============================================================================
# Resource Limits & Tuning (~10 Instances Target Profile)
# ==============================================================================
EVOLUTION_MEM_LIMIT=2048m
EVOLUTION_MEM_RESERVE=512m
EVOLUTION_CPUS=1.5

POSTGRES_MEM_LIMIT=512m
POSTGRES_MEM_RESERVE=128m
POSTGRES_CPUS=1.0

REDIS_MEM_LIMIT=256m
REDIS_MEM_RESERVE=64m
REDIS_CPUS=0.5
```

---

### Entity: Backup Archive Lifecycle & Manifest
Represents a backup archive generated and stored under `/opt/evolution-api/backups/`.

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `filename` | string | Pattern: `evolution-api-backup-YYYYMMDD-HHMMSS.tar.gz` |
| `mode` | enum | `online` (via `pg_dump`) or `cold` (via volume tarball) |
| `retention_limit` | integer | Maximum 10 archives retained concurrently |
| `components` | array | `.env`, `docker-compose.yml`, database snapshot, `instances` archive |
| `permissions` | octal | `0600` (read/write only by `evolution-user` and root) |

#### Lifecycle State Transitions:
1. **Triggered**: Systemd timer (`03:00`) or manual CLI (`--backup` or pre-update).
2. **Discovery**: Inspects running state of `evolution_postgres`.
3. **Capture**: Dumps database (online or cold) + archives WhatsApp instances.
4. **Assembly**: Compresses components into `evolution-api-backup-<timestamp>.tar.gz`.
5. **Retention Enforcement**: Counts total archives in directory; if `count > 10`, oldest `(count - 10)` files are deleted.

---

### Entity: Automation Unit Definitions

#### 1. Systemd Backup Service (`/etc/systemd/system/evolution-api-backup.service`)
```ini
[Unit]
Description=Evolution API Daily Volume Backup
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
User=evolution-user
Group=evolution-user
ExecStart=/usr/local/sbin/service-evolution-api --backup
```

#### 2. Systemd Backup Timer (`/etc/systemd/system/evolution-api-backup.timer`)
```ini
[Unit]
Description=Trigger Daily Evolution API Volume Backup

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```
