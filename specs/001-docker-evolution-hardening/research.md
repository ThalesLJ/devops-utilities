# Research & Technical Decisions: Docker & Evolution API Hardening

**Feature**: [spec.md](./spec.md)  
**Date**: 2026-09-21  
**Status**: Completed

---

## 1. Automated Daily Volume Backups, Cold Backup & Retention

### Decision
Implement an automated daily backup routine orchestrated via a native systemd timer (`evolution-api-backup.timer` triggering `evolution-api-backup.service` at 03:00) with cron fallback (`/etc/cron.daily/evolution-api-backup`). The backup logic in `service-evolution-api` will:
1. Detect whether the `evolution_postgres` container is running.
   - **Online**: Execute live `pg_dump` via `docker exec`.
   - **Offline (Cold Backup)**: Mount the `evolution_postgres_data` volume read-only into an ephemeral `alpine` container and archive the data directory to `evolution-db-cold-<timestamp>.tar.gz`.
2. Archive the `evolution_instances` volume using an ephemeral `alpine` container.
3. Bundle configuration (`.env`, `docker-compose.yml`), database dump/tarball, and instances into a compressed archive: `evolution-api-backup-<timestamp>.tar.gz`.
4. Enforce strict retention: Count existing archives in `/opt/evolution-api/backups/`, sort by creation time, and purge all archives beyond the 10 most recent (`ls -1t ... | tail -n +11 | xargs -r rm -f`).

### Rationale
- Systemd timers are modern, robust, report state via `systemctl list-timers`, and log to `journalctl`.
- Cold backup ensures reliability during maintenance windows or when database containers crash.
- Enforcing max 10 backups prevents silent disk saturation while maintaining over a week of point-in-time recovery.

### Alternatives Considered
- *External backup agents (e.g., Duplicity, BorgBackup)*: Rejected to avoid adding third-party host dependencies.
- *Indefinite retention with time-based purge (e.g., `-mtime +7`)*: Rejected because if backups fail for several days, an `-mtime` purge could delete all remaining backups. A count-based limit (max 10) guarantees at least 10 historical snapshots are always preserved.

---

## 2. Resource Allocation & Parametrization (~10 WhatsApp Instances)

### Decision
Parameterize container memory and CPU allocations in `/opt/evolution-api/.env` and wire them into `docker-compose.yml` with explicit soft reservations and hard limits:

| Service | Hard Limit (`mem_limit`) | Soft Reservation (`mem_reservation`) | CPU Limit (`cpus`) | Default Environment Variable |
| :--- | :--- | :--- | :--- | :--- |
| **Evolution API** | `2048m` (2.0 GB) | `512m` (0.5 GB) | `1.5` | `EVOLUTION_MEM_LIMIT`, `EVOLUTION_MEM_RESERVE`, `EVOLUTION_CPUS` |
| **PostgreSQL** | `512m` (0.5 GB) | `128m` | `1.0` | `POSTGRES_MEM_LIMIT`, `POSTGRES_MEM_RESERVE`, `POSTGRES_CPUS` |
| **Redis** | `256m` (0.25 GB) | `64m` | `0.5` | `REDIS_MEM_LIMIT`, `REDIS_MEM_RESERVE`, `REDIS_CPUS` |

Provide an operational guide `docs/resource-tuning-and-monitoring.md` detailing:
- Sizing baseline: 1 Baileys instance = ~70 MB - 120 MB RAM. 10 instances = ~1.0 GB - 1.2 GB active RAM + 300 MB runtime overhead = ~1.5 GB. 2048 MB hard limit provides a 30% safety cushion for media buffering.
- Live CLI monitoring: `docker stats evolution_api evolution_postgres evolution_redis --no-stream` and alerts.
- Procedure to edit `.env` and restart via `service-evolution-api --restart`.

### Rationale
- Prevents OOM-killer crashes on the host while preventing Node.js garbage collection thrashing.
- Soft reservations guarantee host memory is pre-allocated by the kernel for this service stack.

### Alternatives Considered
- *Hardcoding in `docker-compose.yml`*: Rejected because operators on smaller VPS (e.g. 2 GB RAM) or larger servers (16 GB RAM) need to adjust limits without modifying git-tracked compose files.

---

## 3. Version Pinning (v2.3.7) & Dynamic Safe Update

### Decision
- Default installer image: Pin to `evoapicloud/evolution-api:v2.3.7`.
- `--update` workflow:
  1. Generate pre-update runtime snapshot (`.txt`).
  2. Perform full safety backup (`.tar.gz`).
  3. Query Docker Hub registry API (`https://hub.docker.com/v2/repositories/evoapicloud/evolution-api/tags?page_size=50`) or GitHub releases to identify the latest stable semver v2 release.
  4. Prompt operator with `cur_version -> new_version` confirmation.
  5. Pull new image, recreate containers with `docker compose up -d`, and verify healthcheck.
  6. Trigger automatic rollback prompt if health check fails.

### Rationale
- Pinning avoids breaking changes and unintended database schema migrations.
- Dynamic tag resolution in `--update` allows operators to keep their stack current without waiting for a new installer script release.

### Alternatives Considered
- *Static version list in bash*: Requires updating the script every time Evolution API releases a patch.
- *Defaulting to `latest`*: Rejected; violates SDD and production stability best practices.

---

## 4. Docker Daemon Hardening (`daemon.json`)

### Decision
In `service-docker`, implement safe, idempotent provisioning for `/etc/docker/daemon.json`:
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
If `/etc/docker/daemon.json` already exists:
- Create backup `/etc/docker/daemon.json.bak-<timestamp>`.
- Use a lightweight Python inline helper (guaranteed in standard Linux distros) or jq to merge keys idempotently without destroying existing user settings.
- Run `systemctl reload docker` (or `systemctl restart docker` during initial install).

### Rationale
- `live-restore: true`: Containers stay running even if `dockerd` is upgraded or restarted.
- `log-opts`: Prevents runaway log files from consuming 100% host disk.
- `userland-proxy: false`: Replaces userland proxy processes with direct iptables hairpins, saving memory and CPU.

---

## 5. System User Isolation & Security Hardening

### Decision
1. **Host System Users**:
   - `docker-user`: Provisioned with `useradd -r -s /usr/sbin/nologin -M -c "Docker Service User" docker-user` and added to `docker` group.
   - `evolution-user`: Provisioned with `useradd -r -s /usr/sbin/nologin -d /opt/evolution-api -M -c "Evolution API Service User" evolution-user` and added to `docker` group.
   - Directory ownership: `chown -R evolution-user:evolution-user /opt/evolution-api`, `chmod 750 /opt/evolution-api`, `chmod 600 /opt/evolution-api/.env`.
   - Systemd unit: `User=evolution-user`, `Group=evolution-user`.
2. **Container Security**:
   - `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false` in `.env`.
   - Add `security_opt: [no-new-privileges:true]` across all 3 services.
   - Redis container: Avoid `--requirepass` in command args (which leaks in `ps aux`). Pass password via `REDIS_PASSWORD` environment variable or secure config file and run with unprivileged user `user: "999:999"`.

### Rationale
- Fulfills the updated project constitution requiring unprivileged isolated service accounts.
- Stops credential leakage via process tables and public HTTP endpoints.

---

## 6. In-Container Healthcheck without External Binaries

### Decision
Update `docker-compose.yml` healthcheck test for `evolution-api`:
```yaml
healthcheck:
  test: ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:8080/', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
  interval: 15s
  timeout: 5s
  retries: 5
  start_period: 30s
```

### Rationale
- Minimal Node.js Alpine images do not ship with `curl` by default.
- Node.js is guaranteed to exist and is the native runtime of the container.
- Operates in-process without spawning subshells or failing with exit code 127.
