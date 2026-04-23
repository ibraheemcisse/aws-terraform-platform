# PM-015 — Pod Identity Trust Policy Drift — EBS CSI CrashLoopBackOff

**Date:** April 23, 2026
**Severity:** Medium — latent risk, no immediate user impact
**Status:** Resolved
**Author:** Ibrahim Cisse

---

## Summary

Following the IRSA to Pod Identity migration (PM-014), the EBS CSI controller entered CrashLoopBackOff due to a missing `aws:SourceArn` condition in the Pod Identity trust policy. The controller had 11 restarts before detection. Immediate impact was zero — existing PVCs remained bound. Latent risk was significant — any pod requiring EBS volume provisioning or reattachment would have failed silently.

---

## Detection

Not detected through alerts or manual observation.

Detected during a routine full cluster health check using Kiro CLI with the EKS MCP server, approximately 1 hour after the migration completed.

```
Alert fired:    No
Manual check:   No
Tool detection: Yes — Kiro full health check
Time to detect: ~1 hour post-migration
```

This is a detection gap. The existing CloudWatch alarm for pod restarts was scoped to aggregate cluster restarts, not per-component restarts in kube-system. 11 restarts on a single system component did not breach the aggregate threshold.

---

## Impact

```
Immediate:    None
              Postgres PVC already bound
              Existing volumes unaffected
              API serving requests normally

Latent risk:  High
              Any EBS volume operation would fail:
              - New PVC provisioning
              - Pod restart requiring volume reattachment
              - StatefulSet scaling

Time to latent impact: Unknown — next postgres restart
                        or storage operation
```

---

## Root Cause

The Pod Identity trust policy was missing the `aws:SourceArn` condition:

```hcl
# what was deployed — missing condition
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    # aws:SourceArn condition missing
  }
}
```

Without the `aws:SourceArn` condition, the EKS service cannot assume the role on behalf of the pod. AWS rejects the AssumeRole call with AccessDenied:

```
AccessDenied: Not authorized to perform 
sts:AssumeRoleWithWebIdentity
```

The condition is required to scope the trust to the specific cluster. It is not optional — it is a security requirement that also enables the auth flow to succeed.

---

## Failure Sequence

```
T+0    terraform apply completes
       Pod Identity associations created
       IAM roles trust policies updated
       OIDC conditions removed

T+1    EBS CSI controller pods restart
       (normal behaviour after IAM role change)

T+2    Pods attempt sts:AssumeRole via Pod Identity agent
       Trust policy missing aws:SourceArn condition
       AWS returns AccessDenied

T+3    Pods enter CrashLoopBackOff
       Retry backoff begins
       No alert fires

T+~60m Kiro health check detects 11 restarts
       Diagnoses trust policy misconfiguration
       Cross-references PM-003 as same class of issue
```

---

## Diagnosis Commands

```bash
# Check restart count
kubectl get pods -n kube-system -l app=ebs-csi-controller
# NAME                                  READY   STATUS             RESTARTS
# ebs-csi-controller-xxx                0/6     CrashLoopBackOff   11

# Check logs
kubectl logs -n kube-system -l app=ebs-csi-controller \
  --all-containers=false --tail=20
# AccessDenied: Not authorized to perform
# sts:AssumeRoleWithWebIdentity

# Verify trust policy
aws iam get-role \
  --role-name evershop-dev-ebs-csi-role \
  --query 'Role.AssumeRolePolicyDocument'

# Verify Pod Identity association exists
aws eks list-pod-identity-associations \
  --cluster-name evershop-dev \
  --namespace kube-system \
  --service-account ebs-csi-controller-sa
```

---

## Fix

### Step 1 — Update trust policy in Terraform

```hcl
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
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

### Step 2 — Restart the EBS CSI controller

```bash
kubectl rollout restart deployment ebs-csi-controller \
  -n kube-system

kubectl get pods -n kube-system -l app=ebs-csi-controller
# NAME                                  READY   STATUS    RESTARTS
# ebs-csi-controller-7d87b6fc4-mnqhz   6/6     Running   0
# ebs-csi-controller-7d87b6fc4-zqxhz   6/6     Running   0
```

### Step 3 — Commit and push

```bash
git add modules/eks/iam.tf
git commit -m "fix: add aws:SourceArn condition to Pod Identity trust policy — PM-015"
git push origin main
```

**Time to fix once detected: under 2 minutes.**

---

## Why This Was Missed

```
1. terraform apply completed cleanly
   → no errors, no warnings
   → false signal that migration succeeded

2. Basic pod checks passed
   → kubectl get pods -n healthcare showed Running
   → kube-system not checked routinely

3. Alerts not scoped correctly
   → aggregate restart alarm did not fire
   → no per-component alarm for EBS CSI

4. No post-migration health check protocol
   → no structured check of system components
   → relied on application health as proxy
     for infrastructure health
```

---

## Prevention

```
1. Always include aws:SourceArn in Pod Identity
   trust policies — it is not optional

2. Run full system component health check after
   any IAM or identity change — not just
   application health check

3. Add per-component CloudWatch alarms for
   critical system components:
   EBS CSI controller, ALB controller, CoreDNS

4. Post-migration verification checklist:
   □ kubectl get pods -A | grep -v Running
   □ kubectl get events -A | grep Warning
   □ Check logs of all system components
     for auth errors
```

---

## Detection Gap — Action Required

The existing alarm:
```
evershop-dev-pod-restarts-high
→ aggregate pod restarts > 5
→ did not fire on 11 restarts in kube-system
```

Recommended additional alarms:
```hcl
# Per-component alarm for EBS CSI
resource "aws_cloudwatch_metric_alarm" "ebs_csi_restarts" {
  alarm_name          = "${var.cluster_name}-ebs-csi-restarts"
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "kube-system"
    PodName     = "ebs-csi-controller"
  }
  threshold           = 3
  evaluation_periods  = 1
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  statistic           = "Sum"
}
```

---

## References

- PM-003: EBS CSI addon timeout — IRSA missing on private subnets
- PM-014: IRSA to Pod Identity migration
- Commit: fix: add aws:SourceArn condition to Pod Identity trust policy
