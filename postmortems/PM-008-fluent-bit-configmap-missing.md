# PM-008 — Fluent Bit CreateContainerConfigError

**Date:** April 2026  
**Severity:** Medium — observability degraded  
**Status:** Resolved  

---

## Summary

Fluent Bit DaemonSet pods entered `CreateContainerConfigError` state immediately after deployment. Logs were not flowing to CloudWatch.

---

## Error

```
Error: configmap "fluent-bit-cluster-info" not found
```

---

## Root Cause

The Fluent Bit configuration references a ConfigMap named `fluent-bit-cluster-info` that must contain cluster name and region. This ConfigMap is expected to exist before the DaemonSet starts. It was not created by the Helm chart and was not included in the Terraform module.

---

## Fix

Created the ConfigMap manually first, then added it to the observability module:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-cluster-info
  namespace: amazon-cloudwatch
data:
  cluster.name: evershop-dev
  http.server: "On"
  http.port: "2020"
  read.head: "Off"
  read.tail: "On"
  logs.region: us-east-1
```

---

## Lessons Learned

- DaemonSet configuration dependencies must be provisioned before the DaemonSet
- Helm charts do not always create all required supporting resources — read the values schema carefully
- CloudWatch Container Insights has specific bootstrap requirements not fully documented in the Helm chart README

