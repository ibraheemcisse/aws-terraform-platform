# PM-011 — DNS Flapping to EKS Endpoint

**Date:** April 2026  
**Severity:** Low — intermittent local connectivity  
**Status:** Resolved (workaround)  

---

## Summary

`kubectl` commands intermittently failed with connection timeout errors despite the cluster being healthy. The issue was specific to the local development machine, not the cluster itself.

---

## Error

```
Unable to connect to the server: dial tcp: lookup
{cluster-id}.gr7.us-east-1.eks.amazonaws.com: no such host
```

---

## Root Cause

The local DNS resolver was intermittently failing to resolve the EKS API server endpoint. The resolver was caching a stale NXDOMAIN response. This was a local machine issue — the EKS endpoint was reachable from AWS resources throughout.

---

## Fix

Added a static entry to `/etc/hosts` as a workaround:

```bash
# Get the current IP of the EKS endpoint
nslookup {cluster-id}.gr7.us-east-1.eks.amazonaws.com

# Add to /etc/hosts
echo "{IP_ADDRESS} {cluster-id}.gr7.us-east-1.eks.amazonaws.com" | sudo tee -a /etc/hosts
```

---

## Lessons Learned

- EKS API server endpoints can have multiple IPs and may change — static /etc/hosts entries are a temporary fix only
- For persistent local development, configure a reliable DNS resolver
- This issue does not affect GitHub Actions or any cloud-based pipeline

---

## Note

This is a local development environment issue. Not relevant to production deployments.

