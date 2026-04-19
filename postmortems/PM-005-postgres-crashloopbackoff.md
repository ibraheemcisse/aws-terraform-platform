# PM-005 — PostgreSQL CrashLoopBackOff on EBS Volume

**Date:** April 2026  
**Severity:** High — database unavailable  
**Status:** Resolved  

---

## Summary

PostgreSQL StatefulSet entered CrashLoopBackOff immediately after the EBS PersistentVolume was provisioned and mounted. The pod failed on every restart attempt with a data directory initialisation error.

---

## Error

```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
It contains a lost+found directory, perhaps due to it being a mount point.
Using a mount point directly as the data directory is not recommended.
```

---

## Root Cause

AWS EBS volumes are formatted with `ext4` by default when provisioned via the EBS CSI driver. The `ext4` filesystem creates a `lost+found` directory at the root of the volume. PostgreSQL's `initdb` process checks if the data directory is empty before initialising — `lost+found` causes this check to fail.

The PostgreSQL container was mounting the EBS volume directly at `/var/lib/postgresql/data`, which is also the EBS mount point. PostgreSQL saw a non-empty directory and refused to initialise.

---

## Fix

Added `PGDATA` environment variable to point PostgreSQL to a subdirectory of the mount point:

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata  # subdirectory, not mount root
```

The `pgdata` subdirectory is created fresh by `initdb` inside the EBS volume. `lost+found` remains at the volume root and is ignored.

---

## Lessons Learned

- Never mount EBS volumes directly at the PostgreSQL data directory
- Always use a subdirectory via `PGDATA` — this is documented in the official PostgreSQL Docker image README but easy to miss
- This is a common pattern issue when moving from local Docker volumes (which don't have `lost+found`) to cloud block storage

---

## Prevention

`PGDATA` is now standard in all PostgreSQL StatefulSet manifests in this repository.

