# Quickstart: Complete DevOps Utilities Toolchain Uninstallation

**Feature**: Complete DevOps Utilities Toolchain Uninstallation  
**Branch**: `003-inovatils-uninstall`  
**Date**: 2026-10-08  

---

## Verification Scenarios

### 1. Interactive Toolchain Uninstallation

```bash
# Execute uninstall command
inovatils uninstall

# Output:
#   [!] Complete DevOps Utilities / Inovatils Uninstallation
#   ────────────────────────────────────────────────────────
#   The following will be completely removed:
#     • All deployed utility scripts in /usr/local/sbin
#     • Global CLI wrapper /usr/local/bin/inovatils
#     • State directory and manager ~/.inova-devops
# 
#   The following will NOT be affected and remain active:
#     • Running Docker Engine and containers
#     • Service configurations and data (/opt/evolution-api, .env, volumes)
#     • System users and permissions
# 
#   Proceed with uninstallation? [y/N]: y
# 
#   ✓ Removed deployed utility scripts from /usr/local/sbin
#   ✓ Removed /usr/local/bin/inovatils
#   ✓ Removed ~/.inova-devops
#   ✓ DevOps Utilities / Inovatils has been completely uninstalled.
#   [i] All configured services (Docker, Evolution API, etc.) remain running.
```

Verify verification items:
```bash
which inovatils                   # Expected: not found
ls -d ~/.inova-devops             # Expected: No such file or directory
docker ps                         # Expected: Existing containers still running
```

---

### 2. Unattended Toolchain Uninstallation (Automated Post-Provisioning)

```bash
# Execute unattended uninstallation
inovatils uninstall -y

# Verify exit code
echo $?                           # Expected: 0
```

---

### 3. Preserved Single-Script Removal

```bash
# Remove only disk-health.sh
inovatils uninstall disk-health.sh

# Verify:
which inovatils                   # Expected: /usr/local/bin/inovatils still exists!
ls /usr/local/sbin/disk-health.sh # Expected: No such file or directory
ls ~/.inova-devops/manifest       # Expected: Exists, disk-health.sh removed from it
```
