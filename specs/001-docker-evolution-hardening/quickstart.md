# Quickstart: Docker & Evolution API Hardening & Resource Tuning

**Feature**: [spec.md](./spec.md)  
**Date**: 2026-09-21

---

## 1. Validating User Isolation

Verify that the unprivileged service accounts have been created and assigned properly:

```bash
# Check system accounts
id docker-user
id evolution-user

# Verify directory permissions
ls -ld /opt/evolution-api
# Expected: drwxr-x--- evolution-user evolution-user /opt/evolution-api

# Check systemd service user context
systemctl cat evolution-api.service | grep -E 'User=|Group='
# Expected: User=evolution-user, Group=evolution-user
```

---

## 2. Testing Daily Backups, Cold Backup & 10-File Retention

Run a backup manually and test retention and cold backup behavior:

```bash
# 1. Trigger manual backup
sudo service-evolution-api --backup

# 2. Verify archive was generated with restricted permissions (chmod 600)
ls -la /opt/evolution-api/backups/

# 3. Test Cold Backup (when postgres container is stopped)
docker stop evolution_postgres
sudo service-evolution-api --backup
# Observe cold backup execution message in terminal
docker start evolution_postgres

# 4. Test Retention Limit (max 10 files)
# Check file count
ls -1 /opt/evolution-api/backups/evolution-api-backup-*.tar.gz | wc -l
# Count must never exceed 10.
```

---

## 3. Real-Time Resource Monitoring & Capacity Tuning

Monitor memory and CPU utilization in real time across the stack:

```bash
# Live stream of resource usage
docker stats evolution_api evolution_postgres evolution_redis

# One-shot snapshot
docker stats evolution_api evolution_postgres evolution_redis --no-stream
```

### Tuning Resources for Different Instance Loads

To adjust resources (e.g. scaling from 10 to 20 instances):

1. Edit `/opt/evolution-api/.env`:
   ```bash
   sudo nano /opt/evolution-api/.env
   ```
2. Adjust the desired variables:
   ```env
   EVOLUTION_MEM_LIMIT=3072m
   EVOLUTION_MEM_RESERVE=1024m
   EVOLUTION_CPUS=2.0
   ```
3. Restart the service to apply changes:
   ```bash
   sudo service-evolution-api --restart
   ```

---

## 4. Inspecting Healthcheck Status

Verify that the Evolution API container reports `healthy` via native Node.js HTTP checks:

```bash
# Inspect container health status
docker inspect --format '{{.State.Health.Status}}' evolution_api
# Expected: healthy

# Check recent health logs
docker inspect --format '{{json .State.Health.Log}}' evolution_api | jq
```

---

## 5. Verifying Docker Daemon Baseline

Check `/etc/docker/daemon.json` and verify live-restore:

```bash
# Inspect daemon config
cat /etc/docker/daemon.json

# Check live-restore in docker info
docker info --format '{{.LiveRestoreEnabled}}'
# Expected: true
```
