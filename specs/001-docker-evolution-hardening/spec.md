# Feature Specification: Docker & Evolution API Hardening and Resource Optimization

**Feature Branch**: `001-docker-evolution-hardening`  
**Created**: 2026-09-21  
**Status**: Ready for Planning  
**Input**: User description: "Implementação de melhorias e correções de persistência (backups diários automáticos com retenção de 10 arquivos e suporte a backup a frio), otimização de recursos parametrizados para ~10 instâncias com documentação de tuning/monitoramento, fixação da versão 2.3.7 com atualização para a mais recente no --update, configuração do daemon.json do Docker, segurança com AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false e criação de usuários de sistema isolados (docker-user e evolution-user), e correção do healthcheck da Evolution API."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automated Daily Volume Backups with Cold Backup & Retention Policy (Priority: P1)

As a DevOps engineer or system administrator, I need the Evolution API service to automatically create daily backups of all persistent volumes (PostgreSQL database, session data, instance storage) and retain only the 10 most recent backups, even if the database container is temporarily stopped or offline, so that business data is protected against data loss or disk exhaustion without requiring manual operator intervention.

**Why this priority**: Data persistence and disaster recovery are critical. The current sandbox installation lacks scheduled backups, cold backup capabilities, and rotation policies, risking complete data loss or host disk exhaustion.

**Independent Test**:
Can be verified by executing the backup procedure with both active and stopped containers, simulating multi-day runs to verify that exactly up to 10 archive files are preserved in the backup directory and older archives are automatically pruned.

**Acceptance Scenarios**:
1. **Given** an active Evolution API stack with running database and WhatsApp instances, **When** the scheduled daily backup executes, **Then** a consistent archive containing the database dump and volume files is generated and stored in the backup directory.
2. **Given** the Evolution API stack or PostgreSQL container is stopped or offline, **When** the backup routine runs, **Then** the routine performs a reliable cold backup of the persistent database volume without error.
3. **Given** 10 backup archives already exist in the backup directory, **When** an 11th backup is created, **Then** the oldest backup archive is safely removed, maintaining exactly 10 backups.

---

### User Story 2 - Security Hardening & Unprivileged Service User Isolation (Priority: P1)

As a security auditor and platform operator, I need both the Docker environment and the Evolution API service to run under dedicated, unprivileged system service accounts (`docker-user` and `evolution-user`) and ensure sensitive API credentials are never leaked through public API endpoints, process tables, or container configurations.

**Why this priority**: Operating containers and management scripts as root or exposing instance credentials creates a high-severity security vulnerability that could compromise the entire server.

**Independent Test**:
Can be verified by inspecting user IDs of running services and directory ownership (`/opt/evolution-api`), verifying endpoint `/instance/fetchInstances` returns no instance API keys, and inspecting process lists (`ps aux`) to ensure database and cache credentials are not exposed in plaintext command arguments.

**Acceptance Scenarios**:
1. **Given** a fresh or updated installation of the services, **When** examining the host users and file permissions, **Then** dedicated system users `docker-user` and `evolution-user` exist with no interactive login shell (`/usr/sbin/nologin`), and service directories are owned by their respective isolated accounts with restricted permissions (`chmod 750` / `chmod 600`).
2. **Given** an external request made to the `/instance/fetchInstances` endpoint, **When** reviewing the response payload, **Then** the API keys and sensitive tokens of registered WhatsApp instances are excluded from the output.
3. **Given** the Evolution API systemd service unit, **When** the service is started by systemd, **Then** it runs under the unprivileged `evolution-user` context rather than root.
4. **Given** container runtime inspection (`docker inspect` and `ps aux`), **When** reviewing process command arguments and environment tables, **Then** Redis and PostgreSQL passwords do not appear in command line flags or redundant exposed blocks.

---

### User Story 3 - Parametrized Resource Optimization & Monitoring Guide (Priority: P2)

As a systems administrator scaling WhatsApp integrations, I need clear, configurable CPU and memory resource allocations designed to support approximately 10 concurrent WhatsApp instances, along with an operational guide for real-time monitoring and capacity tuning, so that containers operate reliably without risking host out-of-memory (OOM) crashes or memory starvation.

**Why this priority**: Default container execution without memory or CPU boundaries allows runaway memory usage or memory leaks to crash the entire server, while overly tight limits cause CPU throttling or unexpected container termination.

**Independent Test**:
Can be verified by configuring custom memory limits in the environment file, checking that Docker Compose applies these resource constraints, and verifying that the delivered markdown guide contains accurate sizing calculations and actionable commands for live monitoring.

**Acceptance Scenarios**:
1. **Given** a configuration file with default resource parameters, **When** the stack starts, **Then** memory reservations (soft limits) and memory limits (hard limits) are applied according to the 10-instance target profile (e.g., 2 GB hard limit / 512 MB reservation for the API container).
2. **Given** an operator consulting the repository documentation, **When** accessing the operational tuning guide, **Then** they find concrete instructions on adjusting resource variables in `.env`, sizing formulas per instance count, and command-line steps to monitor real-time resource utilization.

---

### User Story 4 - Version Determinism & Safe Update Path (Priority: P2)

As an operations engineer, I need the default installation to pin stable version 2.3.7 of Evolution API, while providing an explicit, verified update command (`--update`) that can discover, pull, and safely transition all services to the latest available releases with pre-update backups.

**Why this priority**: Relying on the `latest` tag creates silent, unpredictable breaking changes upon restarts, while operators still require a reliable path to update when desired.

**Independent Test**:
Can be verified by performing an installation and confirming that version 2.3.7 is deployed, followed by executing the update routine with validation that new versions are pulled and verified.

**Acceptance Scenarios**:
1. **Given** a new or default deployment, **When** the installation finishes, **Then** the container runs the pinned stable version 2.3.7 rather than an unpinned `latest` tag.
2. **Given** an existing deployment running version 2.3.7, **When** the administrator runs the update routine, **Then** the system checks for the newest available release, creates a safety backup, updates the environment references, redeploys the containers, and verifies application health.

---

### User Story 5 - Docker Daemon Baseline Hardening (Priority: P2)

As an infrastructure administrator, I need the Docker Engine installation script to automatically provision and maintain an optimized `/etc/docker/daemon.json` configuration with live-restore, global log rotation, and optimized networking proxies, so that daemon restarts do not disrupt existing containers and container logs do not exhaust server disk storage.

**Why this priority**: Production Docker hosts require non-disruptive daemon updates and bounded log growth to maintain uptime and prevent disk capacity incidents.

**Independent Test**:
Can be verified by running the Docker installer/updater and inspecting `/etc/docker/daemon.json` to confirm that `live-restore`, `log-driver`, `log-opts`, and `userland-proxy` are correctly configured.

**Acceptance Scenarios**:
1. **Given** a host without `/etc/docker/daemon.json`, **When** the Docker service installer runs, **Then** a valid daemon configuration file is created with `live-restore: true`, JSON file logging with size and file count caps, and `userland-proxy: false`.
2. **Given** an existing `/etc/docker/daemon.json` with user settings, **When** the installer runs, **Then** required production keys are idempotently added or preserved without corrupting existing custom settings.

---

### User Story 6 - Resilient In-Container Healthcheck (Priority: P3)

As a monitoring system or container orchestrator, I need the Evolution API container healthcheck to accurately reflect application availability without relying on optional host binaries like `curl` that may be absent from minimal container images, so that the container status is cleanly reported as `healthy`.

**Why this priority**: A missing `curl` binary in minimal runtime images reports an erroneous `unhealthy` status, misleading monitoring tools and preventing automated health verification.

**Independent Test**:
Can be verified by deploying the Evolution API container and executing `docker inspect` to verify that the health check succeeds with exit code 0 using the built-in runtime environment.

**Acceptance Scenarios**:
1. **Given** the Evolution API container running a minimal runtime image lacking `curl`, **When** Docker evaluates the service health check, **Then** the check executes via native application runtime commands and reports a healthy status.

---

## Edge Cases

- **PostgreSQL Container Offline During Backup**: The backup script must automatically detect that the database container is stopped and switch to a cold backup mechanism using a temporary container to archive the persistent database volume.
- **Disk Space Exhaustion During Backup**: Before generating a new backup archive, the script must verify adequate free space on the destination mount; if space is constrained, pruning of old backups must occur prior to or in conjunction with backup generation.
- **Pre-existing System Users**: If `docker-user` or `evolution-user` already exist on the host, the installation script must detect them, ensure their group memberships (such as `docker`) are intact, and avoid failing the installation.
- **Custom Existing `daemon.json`**: If `/etc/docker/daemon.json` exists with invalid syntax or custom options, the installer must validate JSON integrity before applying modifications and maintain a backup of the previous configuration.
- **Update with Incompatible Migrations**: If the update routine targets a version that fails healthcheck verification, the automated rollback mechanism must restore the previous configuration and database snapshot.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create an unprivileged system service user `docker-user` without interactive shell (`/usr/sbin/nologin`) and ensure appropriate group associations.
- **FR-002**: System MUST create an unprivileged system service user `evolution-user` without interactive shell (`/usr/sbin/nologin`) to own `/opt/evolution-api` and execute the Evolution API service unit.
- **FR-003**: System MUST configure `/etc/systemd/system/evolution-api.service` to execute under `User=evolution-user` and `Group=evolution-user`.
- **FR-004**: System MUST configure the Evolution API `.env` template with `AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false`.
- **FR-005**: System MUST provision or idempotently merge `/etc/docker/daemon.json` to include `"live-restore": true`, `"log-driver": "json-file"`, `"log-opts": {"max-size": "20m", "max-file": "3"}`, and `"userland-proxy": false`.
- **FR-006**: System MUST configure default container resource limits in `.env` and `docker-compose.yml` supporting ~10 WhatsApp instances: Evolution API (limit: 2048m RAM, 1.5 CPUs; reservation: 512m RAM), PostgreSQL (limit: 512m RAM, 1.0 CPU; reservation: 128m RAM), and Redis (limit: 256m RAM, 0.5 CPU; reservation: 64m RAM).
- **FR-007**: System MUST provide a dedicated markdown documentation file (`docs/resource-tuning-and-monitoring.md`) localized in Portuguese (pt-BR) detailing memory/CPU sizing rules per instance count, `.env` adjustment steps, and real-time monitoring via `docker stats`.
- **FR-008**: System MUST pin the default Evolution API image version to `evoapicloud/evolution-api:v2.3.7`.
- **FR-009**: The `--update` command MUST discover and target the latest stable release for each service stack component and perform automated pre-update validation and snapshots.
- **FR-010**: System MUST configure a scheduled automated daily backup routine (via systemd timer or cron) executing at an off-peak time (e.g., 03:00 daily).
- **FR-011**: The backup routine MUST enforce a retention limit of at most 10 backup archives in `${INSTALL_DIR}/backups/`, automatically deleting older archives.
- **FR-012**: The backup routine MUST support cold backups of the persistent database volume (`evolution_postgres_data`) when the PostgreSQL container is not running.
- **FR-013**: The Evolution API service healthcheck in `docker-compose.yml` MUST use native Node.js HTTP evaluation (`node -e "..."`) to eliminate dependency on `curl`.
- **FR-014**: System MUST prevent exposure of Redis authentication passwords in plaintext command-line process tables (`ps aux`).
- **FR-015**: System MUST apply container security options (`no-new-privileges: true` and capability drops where appropriate) across all compose stack services.
- **FR-016**: The project constitution (`constitution.md`) MUST require that all service installation scripts use dedicated, isolated unprivileged system accounts.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of automated backup executions successfully generate a restorable archive containing database and instance volumes, whether services are online or offline.
- **SC-002**: Backup directory storage is strictly bounded to a maximum of 10 archive files under all operating conditions.
- **SC-003**: Evolution API container health status reports `healthy` within 45 seconds of container startup without warnings or errors related to missing system binaries.
- **SC-004**: Public queries to `/instance/fetchInstances` leak 0 instance API keys or credentials.
- **SC-005**: 0 service processes in the Evolution API stack execute under host root privileges during normal systemd service operation.
- **SC-006**: Host Docker daemon reloads or updates without disconnecting or stopping running containers (`live-restore`).

---

## Assumptions

- The target operating system is a supported Linux distribution with `systemd` or standard `cron` capabilities.
- The host server has sufficient memory (at least 3 GB to 4 GB recommended) to support running 10 concurrent WhatsApp instances alongside PostgreSQL and Redis.
- Users executing management commands have appropriate administrative privilege (`sudo`) for the initial setup and user provisioning.
