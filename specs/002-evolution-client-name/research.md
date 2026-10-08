# Technical Research: Dynamic WhatsApp Session Client Name Configuration

**Feature**: Dynamic WhatsApp Session Client Name Configuration  
**Branch**: `002-evolution-client-name`  
**Date**: 2026-09-22  

---

## 1. Evolution API & WhatsApp Baileys Client Naming

### Context
Evolution API uses `@whiskeysockets/baileys` to communicate with WhatsApp Web multi-device endpoints. When connecting, Baileys transmits browser details during the noise protocol handshake.
These details are configured in Evolution API through environment variables:
- `CONFIG_SESSION_PHONE_CLIENT`: The organizational or application label displayed in parentheses on the mobile WhatsApp device (e.g., `Google Chrome (Inova Evolution API)`).
- `CONFIG_SESSION_PHONE_NAME`: The simulated browser identity (e.g., `Chrome`, `Firefox`, `Safari`).

### Decision
- Make `CONFIG_SESSION_PHONE_CLIENT` dynamic and user-configurable during installation.
- Retain default value `"Inova Evolution API"` to prevent breaking existing installations and automated CI/CD scripts.
- Keep `CONFIG_SESSION_PHONE_NAME="Chrome"` static as Chrome is the standard and most reliable browser identifier for Baileys.

---

## 2. Interactive CLI Prompt Pattern

### Context
In `service-evolution-api`, interactive prompts are implemented using the `prompt_value` helper:
```bash
prompt_value() {
    local prompt="$1" default="$2" var_name="$3"
    if [ "$ASSUME_YES" -eq 1 ]; then
        eval "$var_name=\"$default\""
        return 0
    fi
    local answer
    printf '  \033[1;36m[?]\033[0m %s [%s]: ' "$prompt" "$default" > /dev/tty
    if [ -r /dev/tty ]; then
        read -r answer < /dev/tty
    else
        read -r answer
    fi
    if [ -z "$answer" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$answer\""
    fi
}
```

### Decision
Reuse `prompt_value` directly in `main_install()`:
```bash
prompt_value "WhatsApp Session Client Name (displayed in linked devices)" "${CONFIG_SESSION_PHONE_CLIENT:-$DEFAULT_SESSION_PHONE_CLIENT}" CONFIG_SESSION_PHONE_CLIENT
```
This guarantees consistent UX, proper fallback to default when Enter is pressed, and seamless fallback when running in non-TTY environments.

---

## 3. String Quoting and Escaping

### Context
User-provided client names frequently contain spaces, hyphens, and accented characters (e.g. `Minha Empresa - Atendimento`).
- In `.env`: unquoted or improperly formatted strings can cause issues with basic parser scripts. However, standard dotenv syntax allows `KEY=Value with spaces` or `KEY="Value with spaces"`.
- In `docker-compose.yml`: environment section `- CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT:-Inova Evolution API}` safely expands the variable passed from the environment or `.env`.

### Decision
Store in `.env` as:
```text
CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT}
```
And define in `docker-compose.yml` environment:
```yaml
      - CONFIG_SESSION_PHONE_CLIENT=${CONFIG_SESSION_PHONE_CLIENT:-Inova Evolution API}
```
Ensure variables read from `.env` during update routines strip carriage returns (`tr -d '\r'`) to handle Windows CRLF files cleanly.
