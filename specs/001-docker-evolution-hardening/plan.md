# Implementation Plan: Docker & Evolution API Hardening & Resource Optimization

**Branch**: `001-docker-evolution-hardening` | **Date**: 2026-09-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-docker-evolution-hardening/spec.md`

---

## Summary

Implement operational persistence, resource optimization, security hardening, and reliability improvements across `service-docker` and `service-evolution-api`:
1. **Persistence**: Automated daily backups scheduled at 03:00 via systemd timer (or cron), supporting cold backups of `evolution_postgres_data` when the database container is offline, and strictly enforcing a maximum retention of 10 backup archives.
2. **Optimization**: Parametrized CPU and memory allocations in `.env` and `docker-compose.yml` supporting ~10 WhatsApp instances (`EVOLUTION_MEM_LIMIT=2048m`, `EVOLUTION_MEM_RESERVE=512m`, etc.), with an operational guide (`docs/resource-tuning-and-monitoring.md`).
3. **Version Pinning & Safe Update**: Pin default installation to `evoapicloud/evolution-api:v2.3.7`, with an automated `--update` workflow that dynamically discovers and safely applies the latest available stable releases.
4. **Daemon Hardening**: Provision `/etc/docker/daemon.json` with `live-restore: true`, global log rotation (`20m`/`3` files), and `userland-proxy: false`.
5. **Security & Least Privilege**: Enforce unprivileged system user isolation (`docker-user` and `evolution-user`), set `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false`, protect Redis credentials from `ps aux`, and add `no-new-privileges: true`.
6. **Healthcheck Resilience**: Replace missing `curl` with native Node.js HTTP healthcheck in `docker-compose.yml`.

---

## Technical Context

**Language/Version**: Bash 4.x / 5.x (Strict mode: `set -uo pipefail`), Docker Compose V2 YAML (schema 3.8 / Compose Spec).  
**Primary Dependencies**: Docker Engine 24+, Docker Compose V2 (`docker compose`), systemd, coreutils, OpenSSL.  
**Storage**: Docker named volumes (`evolution_instances`, `evolution_store`, `evolution_postgres_data`, `evolution_redis_data`), `/opt/evolution-api/backups/`.  
**Testing**: Shell syntax validation (`bash -n`), automated configuration linters, end-to-end sandbox deployment verification.  
**Target Platform**: Linux (Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora, Arch Linux).  
**Project Type**: Infrastructure Automation & Service Lifecycle Managers (CLI).  
**Performance Goals**: Support ~10 WhatsApp instances with zero host OOM incidents, backup completed in < 30 seconds, healthcheck response < 5 seconds.  
**Constraints**: Zero downtime during Docker daemon updates (`live-restore`), max 10 backup files stored, no plaintext secrets in process tables.  

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Script Architecture and Naming Conventions**: Service managers remain `service-docker` and `service-evolution-api` without file extensions.
- [x] **II. Bash Standard & Execution Resilience**: `set -uo pipefail`, exclusive directory lock (`/tmp/<name>.lock`), auto re-execution under Bash.
- [x] **Principle of Least Privilege & Service User Isolation**: Complies with the updated constitution principle. Services run under dedicated system accounts (`docker-user`, `evolution-user`) with restricted directory permissions (`chmod 750` / `chmod 600`).
- [x] **III. Installation Standards**: Pre-flight environment checks, unattended execution with secure defaults (`-y`), dry-run diagnostics (`-c`).
- [x] **IV. Safe Update Standards**: Runtime state snapshot (.txt) under `/var/log/inova-devops/`, full configuration backup, rollback manifest, automated and on-demand rollback (`--rollback`).
- [x] **V. Destructive Uninstallation**: Prominent warning banner, explicit sudo re-authentication (`sudo -k` + `sudo -v`), typed confirmation keyword `UNINSTALL`.
- [x] **VI. SDD & Artifact Hygiene**: No SDD files leaked to runtime paths.

*Gate status: PASS.*

---

## Project Structure

### Documentation & Specification Artifacts

```text
specs/001-docker-evolution-hardening/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # Phase 0: Technical research & rationale
├── data-model.md        # Phase 1: Entity schemas & data models
├── quickstart.md        # Phase 1: Verification & operational guide
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code & Operational Assets

```text
# Repository Root
├── .specify/
│   ├── feature.json                       # Points to active feature
│   └── memory/
│       └── constitution.md                # Updated constitution with user isolation rule
├── docs/
│   └── resource-tuning-and-monitoring.md  # [NEW] Operational sizing & live monitoring guide
├── service-docker                         # [MODIFY] daemon.json provisioning & docker-user setup
├── service-evolution-api                  # [MODIFY] evolution-user, backup & retention, limits, v2.3.7, healthcheck
└── AGENTS.md                              # [MODIFY] Context reference update
```

---

## Proposed Implementation Details

### Component 1: `service-docker`
1. **System User `docker-user` Provisioning**:
   - Check if `docker-user` exists; if not, create system user with `useradd -r -s /usr/sbin/nologin -M -c "Docker Service User" docker-user`.
   - Add `docker-user` to `docker` group.
2. **`daemon.json` Management**:
   - Create function `configure_docker_daemon()`:
   - Check if `/etc/docker/daemon.json` exists. If present, back up to `/etc/docker/daemon.json.bak-<timestamp>`.
   - Idempotently merge configuration keys (`live-restore: true`, `log-driver: json-file`, `max-size: 20m`, `max-file: 3`, `userland-proxy: false`).
   - Reload/restart Docker daemon safely.

### Component 2: `service-evolution-api`
1. **System User `evolution-user` Provisioning**:
   - Check if `evolution-user` exists; if not, create via `useradd -r -s /usr/sbin/nologin -d /opt/evolution-api -M -c "Evolution API Service User" evolution-user`.
   - Add `evolution-user` to `docker` group.
   - Ensure `/opt/evolution-api` is owned by `evolution-user:evolution-user` (`chmod 750`).
2. **Systemd Service Unit**:
   - Update `setup_systemd_service()` to define `User=evolution-user` and `Group=evolution-user`.
3. **Automated Daily Backups, Cold Backup & 10-Archive Retention**:
   - Update `create_backup()`:
     - Check if `evolution_postgres` container is running.
     - If running: execute `pg_dump`.
     - If stopped: launch ephemeral `alpine` container mounting `evolution_postgres_data` read-only to create database archive.
     - Archive `evolution_instances` volume via ephemeral container.
     - Package into `evolution-api-backup-<timestamp>.tar.gz` with `chmod 600`.
     - Enforce retention: purge archives beyond the 10 newest in `/opt/evolution-api/backups/`.
   - Provision systemd timer `evolution-api-backup.timer` and service `evolution-api-backup.service` (or daily cron job fallback) to run daily at 03:00.
4. **Configuration & Compose Updates**:
   - `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false` in `.env`.
   - Set default image: `DEFAULT_IMAGE="evoapicloud/evolution-api:v2.3.7"`.
   - Add resource variables in `.env` for 10-instance target profile.
   - Add resource limits/reservations (`deploy.resources` / `mem_limit` / `cpus`) in `docker-compose.yml`.
   - Add `security_opt: [no-new-privileges:true]`.
   - Redis container: Avoid `--requirepass` in `command:`; configure authentication without leaking into `ps aux`.
   - Healthcheck: Update to `["CMD", "node", "-e", "require('http').get('http://127.0.0.1:8080/', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]`.
5. **Dynamic Version Discovery in `--update`**:
   - Discover latest stable release from Docker Hub API (or fallback query), report transition, backup, apply and verify.

### Component 3: Operational Guide `docs/resource-tuning-and-monitoring.md`
- Sizing baseline for WhatsApp Baileys instances.
- How to adjust `.env` parameters.
- Monitoring memory and CPU in real time via `docker stats`.

---

## Verification Plan

### Automated Syntax & Quality Checks
1. Validate bash script syntax:
   ```bash
   bash -n service-docker
   bash -n service-evolution-api
   ```
2. Verify YAML syntax of generated docker-compose template:
   ```bash
   docker compose config --dry-run
   ```

### Manual Verification Scenarios
1. Run `service-docker --check-only` and `service-docker -y` to confirm `daemon.json` and `docker-user` creation.
2. Run `service-evolution-api` setup to confirm `evolution-user`, directory permissions, and systemd user context.
3. Trigger `service-evolution-api --backup` multiple times to verify 10-archive retention cap.
4. Stop `evolution_postgres` container and execute `--backup` to verify cold backup handling.
5. Verify `docker inspect evolution_api` reports healthcheck status `healthy`.
6. Query `curl -s http://localhost:8080/instance/fetchInstances` to verify API keys are excluded.
