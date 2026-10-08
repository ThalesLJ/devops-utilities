# Technical Research: Complete DevOps Utilities Toolchain Uninstallation

**Feature**: Complete DevOps Utilities Toolchain Uninstallation  
**Branch**: `003-inovatils-uninstall`  
**Date**: 2026-10-08  

---

## 1. Toolchain Cleanup vs. Service Purge (Constitution Alignment)

### Context
Section V of the project constitution (`Destructive Uninstallation & Purge Standards`) specifies strict safeguards for destructive uninstallation:
- Mandatory visual red alerts itemizing data loss.
- Password re-authentication (`sudo -k` then `sudo -v`).
- Mandatory typed keyword `UNINSTALL` (cannot be bypassed with `-y`).
- Complete termination and purge of containers, systemd units, configuration files, and data directories.

However, the user's explicit requirement for `inovatils uninstall` is:
> *"Importante: Não é para desinstalar os serviços como docker, evolution api e etc. É para desisntalar apenas o software que permite a utilização de sripts .sh , ok? A ideia desse projeto é utilizá-lo apenas durante a configuração inicial de um servidor e depois desinstalar mantendo todos os serviços configurados (como docker e etc)"*

### Decision
- **Differentiate Toolchain Teardown from Service Purge**:
  - Service Purge (`service-* --uninstall` or `--purge`) remains governed by Section V because it destroys persistent data, databases, and container workloads.
  - Toolchain Uninstallation (`inovatils uninstall` / `install.sh uninstall`) is an operational teardown of the temporary provisioning orchestrator. It does **not** destroy business data, Docker containers, or system configurations.
- **Safety Safeguards**:
  - Interactive mode provides a clear informational summary that clearly distinguishes between what is being removed (the CLI toolchain and helper scripts) and what is preserved (Docker, Evolution API, databases, volumes, containers).
  - Requires confirmation in interactive mode (`[y/N]`).
  - Supports non-interactive unattended flag (`-y` / `--yes` / `--force`) so that post-provisioning scripts (cloud-init, Ansible, automated bootstrap pipelines) can clean up automatically without hanging.

---

## 2. In-Flight Bash Script Self-Deletion

### Context
When running `inovatils uninstall`, the process execution path is:
1. User invokes `/usr/local/bin/inovatils uninstall`.
2. `/usr/local/bin/inovatils` executes `bash ~/.inova-devops/install.sh uninstall`.
3. `install.sh` removes scripts in `/usr/local/sbin/`, then removes `/usr/local/bin/inovatils`, and finally removes `~/.inova-devops/` (which contains `install.sh` itself).

Under Linux/Unix filesystem semantics:
- When a file is unlinked (`rm -f`), its directory entry is removed, but the inode and open file descriptors remain accessible to running processes until the file handle is closed.
- However, if the Bash interpreter reads a script in chunks (typical for large scripts) and the file is deleted mid-execution, Bash may raise errors such as `line XXX: unexpected EOF while looking for matching ...` if it attempts to buffer unread portions of the file from disk.

### Decision
- Encapsulate the entire uninstallation logic in a self-contained Bash function (`do_uninstall_toolchain`). Once the function is declared, Bash has parsed and loaded its instructions into memory.
- Execute uninstallation steps in strict dependency order:
  1. Parse arguments and confirm intent (interactive `[y/N]` or automated `-y`).
  2. Enumerate and delete all deployed utility scripts in `/usr/local/sbin/` (or paths tracked in the manifest).
  3. Delete the global CLI wrapper `/usr/local/bin/inovatils`.
  4. Delete state directories: `${HOME}/.inova-devops`, and `/root/.inova-devops` if applicable.
  5. Print the final success confirmation.
  6. Immediately exit cleanly (`exit 0`).

---

## 3. Privilege Elevation & Multi-User State Directories

### Context
- The CLI wrapper is installed in `/usr/local/bin/inovatils` (root-owned, permissions `755`).
- Installed scripts are in `/usr/local/sbin/` (root-owned, permissions `750`).
- State directories may exist in:
  - `${HOME}/.inova-devops` (invoking regular user).
  - `/home/${SUDO_USER}/.inova-devops` (if run as `sudo inovatils`).
  - `/root/.inova-devops` (if run as root or if sudo created root-owned state).

### Decision
- Check whether the executing user is root (`[ "$(id -u)" -eq 0 ]`).
- If not root, invoke `sudo rm -f` for files in `/usr/local/bin` and `/usr/local/sbin`.
- Clean up all relevant state directories:
  ```bash
  rm -rf "${STATE_DIR}" 2>/dev/null || sudo rm -rf "${STATE_DIR}" 2>/dev/null
  if [ -n "${SUDO_USER:-}" ] && [ -d "/home/${SUDO_USER}/.inova-devops" ]; then
      rm -rf "/home/${SUDO_USER}/.inova-devops" 2>/dev/null || sudo rm -rf "/home/${SUDO_USER}/.inova-devops" 2>/dev/null
  fi
  if [ -d "/root/.inova-devops" ]; then
      sudo rm -rf "/root/.inova-devops" 2>/dev/null || true
  fi
  ```
- Remove manager logs (`manager.log`) while leaving service deployment logs in `/var/log/inova-devops/` if other services still reference them.

---

## 4. CLI Argument Parsing and Dispatch

### Context
`inovatils` acts as a wrapper that forwards arguments to `~/.inova-devops/install.sh`.
Currently:
- `inovatils uninstall <script>` removes a specific script.
- `inovatils uninstall` (no arguments) previously attempted to iterate through all scripts and remove them from `/usr/local/sbin`, but did not remove `inovatils` itself or `~/.inova-devops`.

### Decision
- **Unified Behavior**:
  - `inovatils uninstall` (no arguments) or `inovatils uninstall -y`: triggers complete toolchain uninstallation.
  - `inovatils uninstall <script-name>`: removes only the specified script from `/usr/local/sbin` and updates the manifest (preserving the toolchain).
  - `install.sh uninstall`: mirrors the exact same behavior.
- In `inovatils` wrapper:
  - If `uninstall` is passed without a script name, or with `-y`/`--yes`/`--force`, it directly passes to `install.sh`, but if `install.sh` has already deleted the wrapper or state, `inovatils` finishes cleanly.
