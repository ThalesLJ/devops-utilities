# Data Model: Complete DevOps Utilities Toolchain Uninstallation

**Feature**: Complete DevOps Utilities Toolchain Uninstallation  
**Branch**: `003-inovatils-uninstall`  
**Date**: 2026-10-08  

---

## Component Schema

### 1. Toolchain Components (Subject to Uninstallation)

| Component | Filesystem Location | Description | Permissions / Ownership |
| :--- | :--- | :--- | :--- |
| **Global CLI Wrapper** | `/usr/local/bin/inovatils` | Executable wrapper forwarding commands to manager | `755` (root) |
| **Manager Script** | `${STATE_DIR}/install.sh` | Main script loader, installer, and manager | `750` (user/root) |
| **Manifest** | `${STATE_DIR}/manifest` | Pipe-delimited tracking file (`name\|version\|dir`) | `644` (user/root) |
| **Manager Log** | `${STATE_DIR}/manager.log` | Event log for manager operations | `644` (user/root) |
| **State Directory** | `${HOME}/.inova-devops` / `/root/.inova-devops` | Directory housing manager and state | `750` (user/root) |
| **Deployed Scripts** | `/usr/local/sbin/*.sh`, `/usr/local/sbin/service-*` | Standalone utilities and service managers | `750` (root) |

---

### 2. Operational Workloads (Strictly Preserved)

| Component | Filesystem Location / Scope | Impact of `uninstall` |
| :--- | :--- | :--- |
| **Docker Engine & CLI** | `/usr/bin/docker`, `dockerd`, systemd units | **NONE** (Untouched and running) |
| **Docker Containers** | Running container processes (`docker ps`) | **NONE** (Untouched and running) |
| **Persistent Volumes** | Docker named volumes, `/var/lib/docker/volumes` | **NONE** (Untouched) |
| **Service Configurations** | `/opt/evolution-api/`, `.env`, `docker-compose.yml` | **NONE** (Untouched) |
| **Dedicated System Users** | `evolution-user`, `docker-user`, group memberships | **NONE** (Untouched) |
| **Service Execution Logs** | `/var/log/inova-devops/<service>-*.log` | **NONE** (Untouched) |

---

## Lifecycle State Transitions

```mermaid
stateDiagram-v2
    [*] --> Invoked : inovatils uninstall [args]

    Invoked --> CheckArguments : Inspect $1, $2
    
    CheckArguments --> SingleScriptRemoval : Target script specified (e.g. disk-health.sh)
    SingleScriptRemoval --> RemoveSingleFile : rm /usr/local/sbin/<script>
    RemoveSingleFile --> UpdateManifest : manifest_del <script>
    UpdateManifest --> [*] : Exit 0 (Toolchain remains active)

    CheckArguments --> CompleteToolchainTeardown : No target script specified
    
    CompleteToolchainTeardown --> CheckMode : Check for -y / --yes / --force
    CheckMode --> PromptConfirmation : Interactive mode (ASSUME_YES=0)
    CheckMode --> ExecutionConfirmed : Unattended mode (ASSUME_YES=1)
    
    PromptConfirmation --> Aborted : User selects 'N' / Cancels
    Aborted --> [*] : Exit 1 / Abort
    
    PromptConfirmation --> ExecutionConfirmed : User selects 'y'
    
    ExecutionConfirmed --> PurgeDeployedScripts : Remove all scripts in /usr/local/sbin
    PurgeDeployedScripts --> PurgeGlobalCLI : Remove /usr/local/bin/inovatils
    PurgeGlobalCLI --> PurgeStateDirectories : Remove ~/.inova-devops & /root/.inova-devops
    PurgeStateDirectories --> OutputSummary : Display completion message
    OutputSummary --> [*] : Exit 0
```
