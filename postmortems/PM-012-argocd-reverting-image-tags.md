# PM-012 — ArgoCD Reverting Image Tags

**Date:** April 2026  
**Severity:** Medium — deployment instability  
**Status:** Resolved  

---

## Summary

After manually patching the healthcare-api deployment to use an updated image tag, ArgoCD reverted the change within 3 minutes — the intended `selfHeal` behaviour working correctly, but causing confusion during manual debugging sessions.

---

## Root Cause

ArgoCD's `selfHeal: true` policy is working as designed. Any resource that diverges from what is defined in Git is automatically corrected. Manual `kubectl patch` or `kubectl set image` commands are not persistent — ArgoCD treats them as drift and reverts them.

This is not a bug. It is the core GitOps guarantee. The issue was process — attempting to make manual changes in a GitOps-managed environment.

---

## Fix

Updated the image tag in `k8s/healthcare/deployment.yaml` in Git and pushed. ArgoCD synced the new tag within 3 minutes.

```yaml
# k8s/healthcare/deployment.yaml
containers:
  - name: healthcare-api
    image: {account}.dkr.ecr.us-east-1.amazonaws.com/healthcare-api:v1.0.5
```

---

## Lessons Learned

- In a GitOps environment, Git is the only valid way to make changes
- `kubectl patch` is for debugging only — never for persistent changes
- `selfHeal: true` is not optional in a production GitOps setup — it enforces the contract
- If you need to make an emergency change, commit to Git first

---

## Prevention

Added to team working agreement: all manifest changes go through Git. `kubectl apply` and `kubectl patch` are debugging tools, not deployment tools.

