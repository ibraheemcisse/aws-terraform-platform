# PM-001 — Kubernetes Version Incompatibility

**Date:** April 2026  
**Severity:** High — blocked cluster creation  
**Status:** Resolved  

---

## Summary

Node group creation failed immediately after EKS cluster provisioned. Terraform reported `CREATE_FAILED` on the managed node group with no clear error message in the Terraform output.

---

## Timeline

```
T+0    terraform apply initiated — EKS cluster provisioning started
T+12m  EKS cluster reached ACTIVE state
T+13m  Node group provisioning started
T+15m  Node group status: CREATE_FAILED
T+20m  Investigation started
T+35m  Root cause identified — version mismatch
T+45m  Fix applied — cluster recreated with 1.30
T+60m  Nodes joined successfully
```

---

## Root Cause

Terraform configuration specified Kubernetes version `1.29`. AWS EKS had deprecated `1.29` managed node group AMIs in the target region at the time of deployment. The node group could not find a compatible AMI for the launch template, causing silent failure at the AWS layer rather than a Terraform error.

---

## Impact

- Full cluster recreation required (~45 minutes of downtime)
- No data loss — no workloads were deployed yet
- ~$0.10 in wasted EKS control plane cost

---

## Fix

Changed `cluster_version` in `modules/eks/variables.tf` and `envs/dev/terraform.tfvars`:

```hcl
# before
cluster_version = "1.29"

# after
cluster_version = "1.30"
```

---

## Lessons Learned

- Always check the AWS EKS supported version matrix before specifying a version
- Pin to a version that has confirmed managed node group AMI support in your target region
- The EKS console shows available versions — cross-reference before applying

---

## Prevention

Added version validation comment in `modules/eks/variables.tf`:

```hcl
variable "cluster_version" {
  description = "Kubernetes version — verify AMI availability in target region before changing"
  type        = string
  default     = "1.30"
}
```

