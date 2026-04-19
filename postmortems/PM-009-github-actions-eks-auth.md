# PM-009 — GitHub Actions EKS Authentication Failure

**Date:** April 2026  
**Severity:** High — CI/CD pipeline blocked  
**Status:** Resolved  

---

## Summary

GitHub Actions workflows could authenticate to AWS via OIDC successfully but failed when Terraform attempted to interact with the EKS cluster API (Helm releases, Kubernetes resources). The Helm and Kubernetes providers could not reach the cluster.

---

## Error

```
Error: Unauthorized
...
User "arn:aws:iam::{account}:role/github-actions-terraform-role"
cannot get resource "deployments" in API group "apps"
```

---

## Root Cause

Two separate issues:

**Issue 1 — RBAC mapping missing:**
The GitHub Actions IAM role was not mapped in EKS RBAC. EKS uses its own access entry system — having an IAM role is not sufficient. The role must be explicitly granted cluster access via `aws_eks_access_entry` and `aws_eks_access_policy_association`.

**Issue 2 — Provider authentication method:**
The Helm and Kubernetes providers were initially configured with `exec`-based authentication using `aws eks get-token`. This works locally but fails in GitHub Actions because the exec environment does not have the AWS CLI configured the same way.

---

## Fix

**Fix 1 — Added EKS access entries to Terraform:**

```hcl
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::{account}:role/github-actions-terraform-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::{account}:role/github-actions-terraform-role"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
```

**Fix 2 — Switched to token-based provider auth:**

```hcl
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.this.name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
```

Token-based auth uses the AWS provider credentials directly — no exec subprocess needed.

---

## Lessons Learned

- EKS RBAC and AWS IAM are separate systems — having the IAM role is not enough
- `exec`-based Kubernetes provider auth is fragile in CI environments
- Token-based auth is more portable and reliable for automated pipelines
- Always test Terraform pipelines end-to-end in CI early — local success does not guarantee CI success

