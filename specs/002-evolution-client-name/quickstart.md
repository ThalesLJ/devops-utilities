# Quickstart: Dynamic WhatsApp Session Client Name Configuration

**Feature**: Dynamic WhatsApp Session Client Name Configuration  
**Branch**: `002-evolution-client-name`  
**Date**: 2026-09-22  

---

## Verification Scenarios

### 1. Interactive Installation with Custom Name
```bash
# Execute installer without flags
sudo bash ./service-evolution-api

# When prompted:
# WhatsApp Session Client Name (displayed in linked devices) [Inova Evolution API]: Minha Empresa Atendimento

# Verify generated configuration:
grep "CONFIG_SESSION_PHONE_CLIENT" /opt/evolution-api/.env
# Expected: CONFIG_SESSION_PHONE_CLIENT=Minha Empresa Atendimento
```

### 2. Unattended Installation with Custom Flag
```bash
sudo bash ./service-evolution-api -y --client-name "Suporte Tecnico"

# Verify generated configuration:
grep "CONFIG_SESSION_PHONE_CLIENT" /opt/evolution-api/.env
# Expected: CONFIG_SESSION_PHONE_CLIENT=Suporte Tecnico
```

### 3. Unattended Installation with Default Fallback
```bash
sudo bash ./service-evolution-api -y

# Verify generated configuration:
grep "CONFIG_SESSION_PHONE_CLIENT" /opt/evolution-api/.env
# Expected: CONFIG_SESSION_PHONE_CLIENT=Inova Evolution API
```

### 4. Preservation on Safe Update
```bash
sudo bash ./service-evolution-api --update

# Verify custom name was preserved:
grep "CONFIG_SESSION_PHONE_CLIENT" /opt/evolution-api/.env
```
