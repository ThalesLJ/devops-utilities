# Implementation Plan: Complete DevOps Utilities Toolchain Uninstallation

**Branch**: `003-inovatils-uninstall` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-inovatils-uninstall/spec.md`

---

## Summary

Implement a complete, safe toolchain uninstallation command for `inovatils` and `install.sh`:
1. **Toolchain Cleanup**: When `inovatils uninstall` (or `install.sh uninstall`) is invoked without arguments, execute a complete teardown of the devops-utilities orchestration layer—removing all utility and service scripts in `/usr/local/sbin/`, the global CLI `/usr/local/bin/inovatils`, the manager script, manifest, and state directories (`~/.inova-devops` and `/root/.inova-devops`).
2. **Workload & Service Preservation**: Strictly preserve all running services and application configurations (Docker Engine, running containers, Docker Compose stacks like `/opt/evolution-api`, system users `evolution-user`/`docker-user`, persistent volumes, and databases).
3. **Safety & Confirmation UX**: Provide an interactive confirmation dialog with an explicit itemized summary of what will be deleted and what is guaranteed to remain intact.
4. **Unattended Automation**: Support `-y` / `--yes` / `--force` flags for automated cloud-init / post-provisioning cleanup.
5. **Preserved Single-Script Removal**: Retain `inovatils uninstall <script>` (and `inovatils remove <script>`) for backward-compatible removal of individual utilities without touching the toolchain.

---

## Technical Context

**Language/Version**: Bash 4.x / 5.x (Strict mode: `set -uo pipefail`).  
**Primary Dependencies**: GNU coreutils (`rm`, `mkdir`, `cp`, `chmod`, `cut`, `grep`), `sudo`.  
**Storage**: Filesystem paths: `/usr/local/bin/inovatils`, `/usr/local/sbin/*`, `${HOME}/.inova-devops`, `/root/.inova-devops`.  
**Testing**: Shell syntax validation (`bash -n inovatils`, `bash -n install.sh`), interactive confirmation validation, unattended `-y` validation, single-script removal validation.  
**Target Platform**: Linux (Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora, Arch Linux).  
**Project Type**: Infrastructure Automation & Global CLI (`inovatils`).  
**Constraints**: Must never terminate, modify, or uninstall operational services (Docker, Evolution API, containers, volumes). Must handle script in-flight self-deletion safely.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Script Architecture and Naming Conventions**: Primary manager is `install.sh`, global CLI is `/usr/local/bin/inovatils`, utilities reside in `/usr/local/sbin/`, state in `~/.inova-devops/manifest`.
- [x] **II. Bash Standard & Execution Resilience**: Strict mode (`set -uo pipefail`) enforced; elevation via `sudo` limited to privileged system directories (`/usr/local/bin`, `/usr/local/sbin`).
- [x] **III. Installation Standards**: Unattended mode (`-y` / `--yes`) supported for automated environments.
- [x] **IV. Safe Update Standards**: Not applicable to uninstallation, but preserves existing system state.
- [x] **V. Destructive Uninstallation & Purge Standards**:
  - *Distinction*: Section V governs *Service Purges* (e.g. `service-docker --uninstall`, `service-evolution-api --uninstall`) which terminate containers and destroy user data/databases (requiring `sudo -k` and typing `UNINSTALL`).
  - *Toolchain Teardown*: `inovatils uninstall` uninstalls the *provisioning toolchain* after setup while intentionally *preserving* all configured services and databases. It displays clear informational banners and requires confirmation or `-y`.
- [x] **VI. SDD & Development Artifact Hygiene**: SDD artifacts (`.specify/`, `specs/`, `AGENTS.md`) remain excluded from production runtime paths.

*Gate status: PASS.*

---

## Project Structure

### Documentation (this feature)

```text
specs/003-inovatils-uninstall/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # Technical research & safety design
├── data-model.md        # Component schemas & state transitions
├── quickstart.md        # Verification scenarios
├── contracts/
│   └── cli-contract.md  # CLI input/output and behavior contracts
└── checklists/
    └── requirements.md  # Specification quality validation checklist
```

### Source Code (repository root)

```text
# Repository Root
├── inovatils             # [MODIFY] Update argument handling, help usage, and clean delegation for self-uninstallation
├── install.sh            # [MODIFY] Implement do_uninstall_toolchain(), update case u|uninstall, update menu/help
├── README.md             # [MODIFY] Document `inovatils uninstall` and post-provisioning cleanup
└── AGENTS.md             # [MODIFY] Update current feature context link
```

---

## Proposed Implementation Details

### Component 1: `do_uninstall_toolchain` in `install.sh`
1. Define a self-contained function `do_uninstall_toolchain()`:
   - Accept optional flag `--yes` / `-y`.
   - If not `--yes`, prompt user with clear colored box:
     ```text
       ╭──────────────────────────────────────────────────────────╮
       │ [!] Complete DevOps Utilities / Inovatils Uninstallation │
       ╰──────────────────────────────────────────────────────────╯
       This will completely remove:
         • All deployed utility scripts in /usr/local/sbin
         • Global CLI wrapper /usr/local/bin/inovatils
         • Manager and state directory ~/.inova-devops

       This will NOT affect running services:
         • Docker daemon, containers, networks, and images remain running
         • Application configs (/opt/evolution-api, .env, volumes) remain intact
         • System service users and credentials remain intact
     ```
   - Prompt: `ask "Are you sure you want to completely uninstall inovatils and devops-utilities?"`
   - If declined, output `warn "Uninstallation cancelled."` and return 0.
2. Step-by-step uninstallation:
   - Enumerate all scripts in manifest (and repository scripts) and remove matching files in `/usr/local/sbin/` using `sudo rm -f`.
   - Remove `/usr/local/bin/inovatils` using `sudo rm -f`.
   - Remove `${STATE_DIR}` (`~/.inova-devops`).
   - If `${SUDO_USER:-}` is set, remove `/home/${SUDO_USER}/.inova-devops`.
   - If `/root/.inova-devops` exists and user has sudo, remove `/root/.inova-devops`.
   - Print success message:
     ```text
       ✓ DevOps Utilities / Inovatils has been completely uninstalled.
       [i] All configured services (Docker, Evolution API, etc.) remain running.
     ```
   - Exit cleanly (`exit 0`).

### Component 2: CLI Routing in `install.sh`
1. Update `case "$CMD"` for `u|uninstall|remove|rm`:
   - If `$2` is empty:
     - Check if interactive mode or if `--yes` / `-y` was passed. Call `do_uninstall_toolchain 0`.
   - If `$2` is `-y` or `--yes` or `--force`:
     - Call `do_uninstall_toolchain 1`.
   - Else (specific script name passed):
     - Retain existing `do_remove "$2"` to remove only that script.

### Component 3: CLI Wrapper `inovatils`
1. Update `inovatils` wrapper:
   - When called with `uninstall` or `u`:
     - If `$2` is empty or `-y` / `--yes` / `--force`, forward to `install.sh` and allow it to remove the wrapper and exit cleanly.
     - If `$2` is a script name, forward to `install.sh` for single-script removal.
2. Update `inovatils --help` description for `uninstall`:
   - `inovatils uninstall [-y]` -> completely uninstall inovatils and all devops-utilities
   - `inovatils uninstall <script>` -> uninstall a specific script

### Component 4: Interactive Menu Integration
1. In `install.sh` interactive menu (`arrow_menu` and `gum_menu`):
   - Provide an option to "Uninstall Inovatils (DevOps Utilities)".
   - When chosen, invoke `do_uninstall_toolchain 0`.

### Component 5: Documentation Update
1. Update `README.md`:
   - Document the lifecycle recommendation: install during initial server setup, deploy required services, and run `inovatils uninstall` to leave a clean production system.

---

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| :--- | :--- | :--- |
| *None* | Implementation adheres strictly to Bash and Constitution standards. | N/A |
