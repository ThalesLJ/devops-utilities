# Implementation Plan: Dynamic WhatsApp Session Client Name Configuration

**Branch**: `002-evolution-client-name` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-evolution-client-name/spec.md`

---

## Summary

Make the WhatsApp session client name dynamic and interactive in `service-evolution-api`:
1. **Interactive Prompt**: Prompt the operator during interactive installation (`main_install`) for the WhatsApp Session Client Name (`CONFIG_SESSION_PHONE_CLIENT`) using `prompt_value`, defaulting to `"Inova Evolution API"`.
2. **CLI Parameter Support**: Add `--client-name <name>` and `--client-name=<name>` to allow unattended execution and scriptable overrides.
3. **Persistence & Upgrades**: Ensure `CONFIG_SESSION_PHONE_CLIENT` is properly saved to `${INSTALL_DIR}/.env` and `${INSTALL_DIR}/docker-compose.yml`, and preserve the value from existing `.env` files during safe updates (`--update`) or re-deployments.
4. **Visibility & Diagnostics**: Display the configured client name in both the pre-installation confirmation summary and the post-installation completion summary, and document the parameter in `usage()` and `README.md`.

---

## Technical Context

**Language/Version**: Bash 4.x / 5.x (Strict mode: `set -uo pipefail`), Docker Compose V2 YAML.  
**Primary Dependencies**: Docker Engine, Docker Compose V2, coreutils, sed/grep.  
**Storage**: `${INSTALL_DIR}/.env`, `${INSTALL_DIR}/docker-compose.yml`.  
**Testing**: Shell syntax validation (`bash -n service-evolution-api`), dry-run pre-flight check (`-c`), interactive prompt verification, unattended flag verification (`-y`).  
**Target Platform**: Linux (Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora, Arch Linux).  
**Project Type**: Infrastructure Automation & Service Lifecycle Managers (CLI).  
**Constraints**: Must never break unattended mode (`-y`), must maintain backwards compatibility with existing `.env` files, must safely handle strings with spaces and special characters.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Script Architecture and Naming Conventions**: Lifecycle manager remains `service-evolution-api` without file extension.
- [x] **II. Bash Standard & Execution Resilience**: `set -uo pipefail` preserved, no unbound variable errors when reading optional variables from `.env`.
- [x] **Principle of Least Privilege & Service User Isolation**: Generated `.env` maintains `chmod 600` and `evolution-user:evolution-user` ownership.
- [x] **III. Installation Standards**: Unattended mode (`-y`) supported with safe defaults; pre-flight check mode (`-c`) supported without prompting.
- [x] **IV. Safe Update Standards**: Existing `CONFIG_SESSION_PHONE_CLIENT` is extracted from `.env` and preserved across `--update`.
- [x] **V. Destructive Uninstallation**: Unaffected by client name changes.
- [x] **VI. SDD & Artifact Hygiene**: No SDD files leaked to runtime paths.

*Gate status: PASS.*

---

## Project Structure

### Documentation & Specification Artifacts

```text
specs/002-evolution-client-name/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # Technical research & parameter analysis
├── data-model.md        # Entity definitions & configuration schemas
├── quickstart.md        # Verification scenarios & operational usage
├── tasks.md             # Actionable implementation tasks
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code & Operational Assets

```text
# Repository Root
├── service-evolution-api                  # [MODIFY] Add prompt, CLI arg, .env generation, compose file update, summary
├── README.md                              # [MODIFY] Document --client-name option and session client behavior
└── AGENTS.md                              # [MODIFY] Context reference update
```

---

## Proposed Implementation Details

### Component 1: CLI & Defaults in `service-evolution-api`
1. **Declare Defaults**:
   - Add `DEFAULT_SESSION_PHONE_CLIENT="Inova Evolution API"` in the default configuration section.
   - Initialize `CONFIG_SESSION_PHONE_CLIENT=""`.
2. **CLI Argument Parsing**:
   - In the argument parsing `while` loop:
     ```bash
     --client-name)
         CONFIG_SESSION_PHONE_CLIENT="$2"; shift 2 ;;
     --client-name=*)
         CONFIG_SESSION_PHONE_CLIENT="${1#*=}"; shift ;;
     ```
3. **Usage & Documentation**:
   - Add `--client-name NAME` to `usage()` under `Installation Options`.

### Component 2: Interactive Prompt & Validation in `main_install()`
1. In `main_install()` interactive configuration section:
   - Call `prompt_value "WhatsApp Session Client Name (displayed in linked devices)" "${CONFIG_SESSION_PHONE_CLIENT:-$DEFAULT_SESSION_PHONE_CLIENT}" CONFIG_SESSION_PHONE_CLIENT`.
2. In pre-installation summary:
   - Display `printf '    %s: %s\n' "Session Client" "${CONFIG_SESSION_PHONE_CLIENT:-$DEFAULT_SESSION_PHONE_CLIENT}"`.

### Component 3: Configuration Files Generation (`generate_configuration_files()`)
1. **Preserve from Existing `.env`**:
   - If `${env_file}` exists, read existing value:
     `[ -z "$CONFIG_SESSION_PHONE_CLIENT" ] && CONFIG_SESSION_PHONE_CLIENT="$(grep -E '^CONFIG_SESSION_PHONE_CLIENT=' "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' || true)"`
2. **Fallback to Default**:
   - `[ -z "$CONFIG_SESSION_PHONE_CLIENT" ] && CONFIG_SESSION_PHONE_CLIENT="$DEFAULT_SESSION_PHONE_CLIENT"`.
3. **Write to `.env`**:
   - Write `CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT}`.
4. **Write to `docker-compose.yml`**:
   - Use `- CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT:-Inova Evolution API}`.

### Component 4: Post-Install Summary
1. In `print_section "Installation Complete"`:
   - Display `printf '    %s %s\n' "Session Client:" "${C_CYAN}${CONFIG_SESSION_PHONE_CLIENT}${C_RESET}"`.
