# PM-014 — IRSA to Pod Identity Migration

**Date:** April 23, 2026
**Severity:** None — planned migration, zero downtime
**Status:** Resolved
**Author:** Ibrahim Cisse

---

## Summary

Migrated all five IAM roles across the platform from IRSA (IAM Roles for Service Accounts) to EKS Pod Identity. Migration completed successfully with zero downtime. A trust policy misconfiguration was introduced during the migration — documented separately in PM-015.

---

## Background

IRSA has been the standard pattern for pod-level AWS access since EKS 1.13. It works by projecting a signed JWT into the pod, which is exchanged for temporary AWS credentials via STS. The trust policy on each IAM role references the specific OIDC provider URL of the cluster — creating a coupling between IAM roles and a specific cluster instance.

Pod Identity removes this coupling. A DaemonSet agent running on every node handles the token exchange. IAM roles use a generic trust policy with no cluster-specific references. The binding between role and workload is managed through an `aws_eks_pod_identity_association` resource rather than a service account annotation.

---

## Motivation

```
Primary:   IAM roles tied to cluster OIDC URL
           → rebuild cluster, OIDC ID changes
           → all trust policies break
           → manual update of every role required

Secondary: Service account annotations create
           implicit coupling between Helm chart
           values and IAM role ARNs

Tertiary:  AWS recommends Pod Identity as the
           current best practice for EKS 1.24+
```

---

## Scope

Five roles migrated across three Terraform modules:

```
modules/eks/iam.tf:
  evershop-dev-ebs-csi-role     → kube-system / ebs-csi-controller-sa
  evershop-dev-ecr-pull-role    → healthcare / healthcare-sa

modules/alb-controller/main.tf:
  evershop-dev-alb-controller-role → kube-system / aws-load-balancer-controller

modules/observability/main.tf:
  evershop-dev-cloudwatch-agent-role → amazon-cloudwatch / cloudwatch-agent
  evershop-dev-fluent-bit-role       → amazon-cloudwatch / fluent-bit
```

---

## Changes Made

### 1. Added Pod Identity Agent addon

```hcl
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.general]
}
```

### 2. Replaced OIDC trust policies with Pod Identity trust policy

Before:
```hcl
data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${oidc_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
```

After:
```hcl
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_eks_cluster.this.arn]
    }
  }
}
```

### 3. Added Pod Identity associations per workload

```hcl
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
  tags            = var.tags
}
```

### 4. Removed service account annotations from Helm values

ALB controller Helm release — removed:
```hcl
set {
  name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value = aws_iam_role.alb_controller.arn
}
```

### 5. Removed OIDC variables from module interfaces

Removed from modules/alb-controller/variables.tf and modules/observability/variables.tf:
```hcl
variable "oidc_provider_arn" { ... }
variable "oidc_provider_url" { ... }
```

Removed from envs/dev/main.tf module calls:
```hcl
oidc_provider_arn = module.eks.oidc_provider_arn
oidc_provider_url = module.eks.oidc_provider_url
```

---

## Apply Output

```
Plan: 9 to add, 6 to change, 1 to destroy

Added:
+ module.eks.aws_eks_addon.pod_identity_agent
+ module.eks.aws_eks_pod_identity_association.ebs_csi
+ module.eks.aws_eks_pod_identity_association.ecr_pull
+ module.alb_controller.aws_eks_pod_identity_association.alb_controller
+ module.observability.aws_eks_pod_identity_association.cloudwatch_agent
+ module.observability.aws_eks_pod_identity_association.fluent_bit

Updated:
~ module.eks.aws_iam_role.ebs_csi (trust policy)
~ module.eks.aws_iam_role.ecr_pull (trust policy)
~ module.alb_controller.aws_iam_role.alb_controller (trust policy)
~ module.observability.aws_iam_role.cloudwatch_agent (trust policy)
~ module.observability.aws_iam_role.fluent_bit (trust policy)
~ module.alb_controller.helm_release.alb_controller (annotation removed)

Apply complete: 9 added, 6 changed, 1 destroyed
```

---

## Verification

```bash
# Pod Identity agent running on all nodes
kubectl get pods -n kube-system | grep pod-identity
eks-pod-identity-agent-6289z   1/1   Running   0   17m
eks-pod-identity-agent-kh5hw   1/1   Running   0   17m
eks-pod-identity-agent-mbhdr   1/1   Running   0   17m

# Endpoint healthy post-migration
curl http://<ALB>/health
{"status":"healthy","database":"connected"}
```

---

## Issue Introduced

The initial migration was missing the `aws:SourceArn` condition in the trust policy. This caused the EBS CSI controller to enter CrashLoopBackOff immediately after migration. Documented in PM-015.

---

## Comparison: IRSA vs Pod Identity

```
                    IRSA              Pod Identity
OIDC provider       Required          Not needed
Trust policy        Cluster-specific  Generic + SourceArn
Service account     Annotation needed Association resource
Token exchange      Pod handles it    Agent handles it
Cluster portability No                Yes
Module coupling     OIDC vars passed  No OIDC vars needed
```

---

## Prevention

```
1. Always include aws:SourceArn condition in
   Pod Identity trust policies
2. Run full health check after any IAM migration
3. Verify each component independently —
   a clean apply does not mean all components work
```

---

## References

- PM-015: Trust policy drift — EBS CSI CrashLoopBackOff
- Commit: feat: migrate from IRSA to EKS Pod Identity across all 5 roles
- AWS docs: EKS Pod Identity
