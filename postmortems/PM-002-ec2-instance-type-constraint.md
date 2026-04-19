# PM-002 — EC2 Instance Type Free Tier Constraint

**Date:** April 2026  
**Severity:** Low — cost concern  
**Status:** Resolved  

---

## Summary

Initial configuration used `t3.medium` for EKS worker nodes. This exceeded the free tier threshold and would have resulted in unexpected billing during development. Changed to `t3.small` to stay within acceptable cost limits for a portfolio lab environment.

---

## Root Cause

Default instance type recommendation for EKS workloads is `t3.medium`. For a production environment this is appropriate. For a single-account portfolio lab running intermittently, it generates unnecessary cost during idle periods.

---

## Impact

- No cluster failure — purely a cost optimisation decision
- `t3.medium`: ~$0.0416/hr per node = ~$3/day for 2 nodes
- `t3.small`: ~$0.0208/hr per node = ~$1.50/day for 2 nodes

---

## Fix

```hcl
# envs/dev/terraform.tfvars

# before
node_instance_types = ["t3.medium"]

# after
node_instance_types = ["t3.small"]
```

---

## Lessons Learned

- t3.small has a hard limit of 11 pods per node (see PM-010)
- Right-sizing for dev environments is a genuine Cost Optimization decision, not just penny-pinching
- The WAF Cost Optimization pillar explicitly covers right-sizing per environment

---

## Prevention

Instance type is now parameterised via `tfvars` per environment:

```hcl
# envs/dev/terraform.tfvars
node_instance_types = ["t3.small"]

# envs/prod/terraform.tfvars (when provisioned)
node_instance_types = ["t3.medium"]
```

Same module, different values — no code duplication.

