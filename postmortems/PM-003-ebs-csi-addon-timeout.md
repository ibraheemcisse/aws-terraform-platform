# PM-003 — EBS CSI Addon Timeout on Private Subnets

**Date:** April 2026  
**Severity:** High — blocked addon installation, repeated 20-minute timeouts  
**Status:** Resolved  

---

## Summary

The `aws-ebs-csi-driver` EKS addon consistently timed out at the 20-minute Terraform timeout threshold. The addon remained in `CREATING` state indefinitely. The issue occurred three times across two separate apply attempts before the root cause was identified.

---

## Timeline

```
T+0    terraform apply — ebs_csi addon creation started
T+20m  Terraform timeout: "waiting for state to become ACTIVE"
T+21m  Addon tainted, second attempt on re-apply
T+40m  Second timeout — same error
T+41m  kubectl logs investigation started
T+45m  Root cause identified in ebs-plugin container logs
T+50m  IRSA role added to Terraform code
T+52m  Role created, policy attached
T+53m  Addon creation started with service_account_role_arn
T+54m  Addon reached ACTIVE state
```

---

## Root Cause

The EBS CSI driver requires AWS API access to call `ec2:DescribeAvailabilityZones` and related EC2 APIs on startup. Without an explicit IRSA role, the driver falls back to the EC2 Instance Metadata Service (IMDS) to obtain credentials.

EKS worker nodes are in **private subnets**. The IMDS endpoint (`169.254.169.254`) is reachable from private subnets, but the IMDSv2 token request timed out due to network configuration — the driver could not obtain node-level credentials.

The exact error from `kubectl logs`:

```
get identity: get credentials: failed to refresh cached credentials,
no EC2 IMDS role found, operation error ec2imds: GetMetadata,
canceled, context deadline exceeded
```

Without credentials, the driver's health check failed, the pod entered `CrashLoopBackOff`, and the addon never reached `ACTIVE`.

---

## Impact

- 3 × 20-minute Terraform timeouts (~60 minutes of blocked work)
- Addon tainted twice in Terraform state
- Manual `aws eks delete-addon` and `terraform state rm` required to clean up

---

## Fix

Added an IRSA role scoped to the EBS CSI controller service account:

```hcl
# modules/eks/iam.tf

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
```

Then wired it to the addon:

```hcl
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn  # this line was missing

  depends_on = [
    aws_eks_node_group.general,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}
```

After the fix, the addon reached `ACTIVE` in **39 seconds**.

---

## Lessons Learned

- Any EKS addon that calls AWS APIs needs an explicit IRSA role when nodes are in private subnets
- The IMDS fallback works in tutorials (public subnets, permissive node IAM) but fails in hardened environments
- `service_account_role_arn` is not optional for addons that need AWS access — it is required
- The 20-minute Terraform timeout is a symptom, not the cause — always check pod logs first

---

## Prevention

All future addon installations with AWS API dependencies will include `service_account_role_arn` as a non-negotiable field. Added a comment in the module:

```hcl
# WAF:Security — service_account_role_arn is required
# without it the driver falls back to IMDS which fails on private subnets
```

