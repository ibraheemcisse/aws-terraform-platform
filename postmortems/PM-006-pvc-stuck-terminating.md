# PM-006 — PersistentVolumeClaim Stuck Terminating

**Date:** April 2026  
**Severity:** Medium — blocked redeployment  
**Status:** Resolved  

---

## Summary

After deleting the PostgreSQL StatefulSet during a troubleshooting cycle, the associated PersistentVolumeClaim (PVC) remained in `Terminating` state indefinitely. The PVC could not be deleted through normal means, blocking recreation of the StatefulSet.

---

## Root Cause

The PVC had a `kubernetes.io/pvc-protection` finalizer applied automatically by Kubernetes. This finalizer prevents PVC deletion while a pod is still using the volume. The StatefulSet had been deleted but the pod was in a terminating state and still held a reference to the volume, creating a deadlock:

```
Pod terminating → waiting for volume to detach
PVC terminating → waiting for pod to release volume
```

---

## Fix

Patched the finalizer off the PVC manually:

```bash
kubectl patch pvc postgres-data-postgres-0 -n healthcare \
  -p '{"metadata":{"finalizers":[]}}' \
  --type=merge
```

PVC deleted immediately after the finalizer was removed. EBS volume was also manually deleted from the AWS console to avoid orphaned storage costs.

---

## Lessons Learned

- PVC protection finalizers are a safety mechanism — bypassing them should be deliberate
- Always verify the EBS volume is deleted in AWS after force-deleting a PVC — Kubernetes does not always clean up the underlying cloud resource
- StatefulSet deletion order matters: scale to 0 first, then delete the StatefulSet, then delete PVCs

---

## Prevention

Added to runbook: when deleting StatefulSets, always follow the sequence:

```bash
# 1. Scale to zero first
kubectl scale statefulset postgres --replicas=0 -n healthcare

# 2. Wait for pod termination
kubectl wait --for=delete pod/postgres-0 -n healthcare --timeout=60s

# 3. Delete StatefulSet
kubectl delete statefulset postgres -n healthcare

# 4. Delete PVC (should now succeed without patching)
kubectl delete pvc postgres-data-postgres-0 -n healthcare
```

