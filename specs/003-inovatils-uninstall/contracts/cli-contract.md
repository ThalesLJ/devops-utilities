# Interface Contract: Inovatils Uninstallation CLI

**Feature**: Complete DevOps Utilities Toolchain Uninstallation  
**Branch**: `003-inovatils-uninstall`  
**Date**: 2026-10-08  

---

## 1. Global CLI Commands (`inovatils`)

### 1.1 Complete Uninstallation (Interactive)

```bash
inovatils uninstall
# or alias
inovatils u
```

**Behavior**:
- Inspects system for installed scripts, manifest, and binaries.
- Prints banner with scope of deletion and explicitly highlights preserved services.
- Prompts for confirmation:
  ```text
  [!] Complete DevOps Utilities / Inovatils Uninstallation
  ---------------------------------------------------------
  The following will be completely removed:
    • All deployed utility scripts in /usr/local/sbin
    • Global CLI wrapper /usr/local/bin/inovatils
    • State directory and manager ~/.inova-devops

  The following will NOT be affected and remain active:
    • Running Docker Engine and containers
    • Service configurations and data (/opt/evolution-api, .env, volumes)
    • System users and permissions

  Proceed with uninstallation? [y/N]:
  ```
- If confirmed: proceeds with purge and outputs completion message.
- If declined: exits with code 0 or 1 without making changes.

---

### 1.2 Complete Uninstallation (Unattended / Automated)

```bash
inovatils uninstall -y
# or
inovatils uninstall --yes
# or
inovatils uninstall --force
```

**Behavior**:
- Executes without blocking on user input.
- Purges all toolchain components immediately.
- Prints concise status lines.
- Exits with return code `0`.

---

### 1.3 Single Script Removal (Backward-Compatible)

```bash
inovatils uninstall <script-name>
# or
inovatils remove <script-name>
# or
inovatils u <script-name>
```

**Example**:
```bash
inovatils uninstall disk-health.sh
```

**Behavior**:
- Removes only the targeted script from `/usr/local/sbin` (or manifest path).
- Deletes script entry from manifest (`manifest_del`).
- Leaves `inovatils` CLI and `~/.inova-devops/` untouched.

---

## 2. Manager CLI Commands (`install.sh`)

Matches the exact contract as `inovatils`:

| Command | Action |
| :--- | :--- |
| `bash install.sh uninstall` | Interactive complete toolchain uninstallation |
| `bash install.sh uninstall -y` | Non-interactive complete toolchain uninstallation |
| `bash install.sh uninstall <script>` | Selective single-script removal |
| `bash install.sh remove <script>` | Alias for single-script removal |
| `bash install.sh u` | Alias for complete or single-script uninstallation |

---

## 3. Exit Codes

| Exit Code | Meaning |
| :--- | :--- |
| `0` | Uninstallation succeeded, or interactive prompt was cancelled gracefully. |
| `1` | Error occurred (e.g. missing sudo privileges, network or filesystem write failure). |
