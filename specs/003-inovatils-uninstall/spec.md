# Feature Specification: Complete DevOps Utilities Toolchain Uninstallation

**Feature Branch**: `003-inovatils-uninstall`  
**Created**: 2026-10-08  
**Status**: Ready for Planning  
**Input**: User description: "Preciso de um novo comando para o script do inovatils chamado 'uninstall' para desinstalar TUDO relacionado ao projeto devops-utilities / inovatils. Importante: Não é para desinstalar os serviços como docker, evolution api e etc. É para desisntalar apenas o software que permite a utilização de sripts .sh , ok? A ideia desse projeto é utilizá-lo apenas durante a configuração inicial de um servidor e depois desinstalar mantendo todos os serviços configurados (como docker e etc)"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete Project & CLI Toolchain Uninstallation (Priority: P1)

As a system administrator or DevOps engineer who has completed the initial setup and configuration of a Linux server using the `devops-utilities` suite, I want to execute `inovatils uninstall` (or `install.sh uninstall`) to completely remove the management toolchain—including the global `inovatils` CLI command, the manager script, the manifest, local state directories, and all installed `.sh` and `service-*` utility scripts—while leaving all deployed services (such as Docker, Evolution API, containers, volumes, networks, and system users) intact and running, so that no temporary provisioning software remains on the production host.

**Why this priority**: The primary architectural purpose of `devops-utilities` is initial server provisioning and onboarding. Once services are configured and operational, security and maintenance best practices dictate eliminating temporary provisioning tooling and scripts. Delivering a clean, complete uninstallation of the toolchain without impacting configured services is the fundamental requirement.

**Independent Test**:
On a machine with `inovatils`, `install.sh`, and utility scripts installed in `/usr/local/sbin` alongside active services (e.g., Docker running), run `inovatils uninstall`, review the confirmation prompt and scope summary, confirm the action, and verify that:
1. `/usr/local/bin/inovatils` is removed.
2. All deployed utility scripts in `/usr/local/sbin` are removed.
3. State directories (`~/.inova-devops/` and `/root/.inova-devops/` if created) are removed.
4. Docker containers, images, volumes, and `/opt/evolution-api` remain fully operational and untouched.

**Acceptance Scenarios**:
1. **Given** an interactive terminal session where `inovatils` and utility scripts are installed, **When** the user executes `inovatils uninstall` without arguments, **Then** the system displays a clear warning banner listing everything that will be removed (CLI, manager, scripts, state directory) and explicitly stating that running services (Docker, Evolution API, etc.) will NOT be stopped or removed.
2. **Given** the uninstallation confirmation prompt, **When** the user confirms (e.g., typing `y` or Enter), **Then** all toolchain files and directories are removed, a success message is displayed, and the command exits with code 0.
3. **Given** the uninstallation confirmation prompt, **When** the user declines (e.g., typing `n`), **Then** the uninstallation aborts immediately and no files or configurations are modified.

---

### User Story 2 - Automated Non-Interactive Uninstallation via Flag (Priority: P2)

As an automation engineer using CI/CD pipelines, cloud-init scripts, or Ansible playbooks for server bootstrap, I want to execute `inovatils uninstall -y` (or `--yes` / `--force`) to purge the toolchain without blocking on interactive prompts, enabling fully automated zero-touch provisioning and subsequent cleanup.

**Why this priority**: Automated deployments require hands-free completion. Teardown of bootstrap tooling must run unattended without hanging for stdin input, consistent with Section III (Installation Standards) of the project constitution.

**Independent Test**:
Execute `inovatils uninstall -y` in a non-interactive shell and verify that the command executes to completion with exit code 0, removing all toolchain artifacts without waiting for terminal input.

**Acceptance Scenarios**:
1. **Given** an automated unattended environment or CLI invocation with `-y` or `--yes`, **When** `inovatils uninstall -y` is executed, **Then** all toolchain components are purged without requesting manual confirmation.
2. **Given** an unattended execution, **When** the purge finishes, **Then** a final status summary is printed to stdout and the process exits with code 0.

---

### User Story 3 - Selective Single-Script Removal Preserved (Priority: P3)

As a system operator maintaining a server where `inovatils` is actively used, I want `inovatils uninstall <script>` (and its alias `inovatils remove <script>`) to continue removing only the specified script from `/usr/local/sbin/` and updating the manifest, without deleting the `inovatils` CLI itself or other installed utilities.

**Why this priority**: Preserves backward compatibility. Users who only want to remove a single script (e.g., `inovatils uninstall threat-scan.sh`) must not have their entire toolchain removed unexpectedly.

**Independent Test**:
Run `inovatils uninstall disk-health.sh` when multiple utilities are installed, and verify that only `disk-health.sh` is removed from `/usr/local/sbin` and the manifest, while `inovatils` and other scripts remain functional.

**Acceptance Scenarios**:
1. **Given** multiple scripts installed in `/usr/local/sbin`, **When** `inovatils uninstall <script-name>` is invoked with a specific script name, **Then** only that targeted script is deleted from the filesystem and manifest.
2. **Given** invocation with a specific script name, **When** uninstallation completes, **Then** the global CLI `inovatils` and the state directory `~/.inova-devops/` remain fully intact.

---

## Edge Cases

- **Root vs. Non-Root Execution**:
  - The CLI wrapper lives in `/usr/local/bin/` and scripts live in `/usr/local/sbin/`, requiring root permissions for deletion.
  - When invoked by a regular user, the uninstallation routine must elevate via `sudo` to remove system binaries, while cleaning the user's `$HOME/.inova-devops` without leaving root-owned remnants.
  - If previous commands were run under `sudo`, `/root/.inova-devops` might exist and must also be cleaned.
- **Executing Script Self-Deletion**:
  - The uninstallation process deletes `inovatils` and `install.sh` while bash is executing them.
  - In Unix/Linux, unlinking open file descriptors does not cause an immediate runtime crash, but subsequent command substitutions or subshell reads of the file could fail if not loaded into memory.
  - The script must perform deletions in a safe sequence (first managed scripts, then global CLI wrapper `/usr/local/bin/inovatils`, then state files, and finally directory removal and exit).
- **Service Isolation**:
  - Docker containers, systemd service units (e.g., `docker.service`, `docker.socket`), user groups (e.g., `docker`, `evolution-user`), environment files (`/opt/evolution-api/.env`), and persistent volumes must NEVER be targeted by this uninstallation.
- **Partial or Broken State**:
  - If `/usr/local/bin/inovatils` exists but `~/.inova-devops` is missing, or vice versa, the uninstallation command must handle missing files idempotently without throwing fatal errors.
- **Logging Cleanup**:
  - Manager log (`~/.inova-devops/manager.log`) is deleted with the state directory.
  - Operational service logs in `/var/log/inova-devops/` must be evaluated: manager run logs may be removed or left according to retention, but service health and deployment records are preserved.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an uninstallation workflow when `uninstall` (or `u`) is invoked without arguments: `inovatils uninstall` and `install.sh uninstall`.
- **FR-002**: System MUST remove the global CLI wrapper located at `/usr/local/bin/inovatils` (or custom `$BIN_TARGET`).
- **FR-003**: System MUST remove all deployed scripts managed by the project in `/usr/local/sbin/` (or target directories recorded in the manifest or matching repository utilities).
- **FR-004**: System MUST remove the state directory `${HOME}/.inova-devops/` (including `install.sh`, `manifest`, and manager logs).
- **FR-005**: System MUST detect and remove `/root/.inova-devops/` if the command is executed with `sudo` or if root-level state exists.
- **FR-006**: System MUST explicitly PRESERVE all system services, Docker Engine, Docker Compose, containers, persistent volumes, environment files (`/opt/*`), and service users (`evolution-user`, `docker-user`).
- **FR-007**: System MUST display an interactive warning summary detailing what will be deleted and what will be preserved, requiring confirmation before proceeding in interactive mode (`ASSUME_YES=0`).
- **FR-008**: System MUST support unattended execution via `-y` / `--yes` / `--force`, bypassing the confirmation prompt for automated post-provisioning cleanup.
- **FR-009**: System MUST preserve single-script uninstallation when a script name is supplied: `inovatils uninstall <script>` and `inovatils remove <script>`.
- **FR-010**: System MUST update command usage documentation (`usage()` / `--help`) in both `inovatils` and `install.sh` to clearly distinguish complete toolchain uninstallation from single-script removal.

### Key Entities

- **DevOps Utilities Toolchain**:
  - `Global CLI Wrapper`: `/usr/local/bin/inovatils` (executable script).
  - `Manager Script`: `${HOME}/.inova-devops/install.sh` (or `/root/.inova-devops/install.sh`).
  - `State & Manifest`: `${HOME}/.inova-devops/manifest` and `${HOME}/.inova-devops/manager.log`.
  - `Deployed Utility Scripts`: `/usr/local/sbin/*.sh` and `/usr/local/sbin/service-*` tracked in manifest or corresponding to repository scripts.
- **Preserved Operational Workloads**:
  - `Docker Runtime`: Docker Engine packages, `dockerd`, systemd units, Docker CLI, compose plugin.
  - `Service Workloads`: Evolution API, Postgres, Redis, or any containerized services.
  - `Service Configurations & Volumes`: `/opt/evolution-api/`, `.env` files, Docker volumes, container networks.
  - `Dedicated System Users`: `evolution-user`, `docker-user`, group memberships.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of devops-utilities / inovatils files (CLI wrapper, manager script, state directory, and deployed `/usr/local/sbin` scripts) are purged upon complete uninstallation.
- **SC-002**: Zero external services, containers, or host packages (Docker, Evolution API, `/opt/*`, volumes) are stopped, removed, or altered during uninstallation.
- **SC-003**: Unattended execution (`inovatils uninstall -y`) completes in under 10 seconds without interactive stalls or prompts.
- **SC-004**: Interactive execution clearly communicates to the operator that running services are safe and asks for explicit confirmation before deleting files.
- **SC-005**: Single-script removal (`inovatils uninstall <script>`) remains 100% functional without removing the toolchain.

---

## Assumptions

- The operator is executing `inovatils uninstall` either as `root` or as a user with `sudo` privileges capable of removing files in `/usr/local/bin/` and `/usr/local/sbin/`.
- Deleting the running bash script files (`inovatils` and `install.sh`) at the tail end of execution is safe under Linux kernel file unlinking semantics.
- Users wishing to completely uninstall a service itself (e.g. Evolution API or Docker) will use the dedicated service-level purge commands (`service-evolution-api --uninstall` or `service-docker --uninstall`) prior to or independently of the toolchain uninstallation.
