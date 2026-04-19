# PM-007 — ArgoCD CRD Race Condition

**Date:** April 2026  
**Severity:** High — blocked Terraform apply  
**Status:** Resolved  

---

## Summary

`terraform apply` failed when attempting to create the ArgoCD root Application manifest using the `kubernetes_manifest` resource. Terraform validated the manifest at plan time before ArgoCD's Custom Resource Definitions (CRDs) existed in the cluster, causing the provider to reject the resource as an unknown type.

---

## Error

```
Error: Failed to determine GroupVersionResource for manifest
...
no matches for kind "Application" in group "argoproj.io"
```

---

## Root Cause

The Terraform Kubernetes provider validates `kubernetes_manifest` resources against the cluster's API server at plan time. When ArgoCD is being installed in the same apply run, the `Application` CRD does not exist yet when validation occurs. Even with `depends_on` pointing to the Helm release, plan-time validation runs before any resources are created.

This is a known limitation of the `kubernetes_manifest` resource — it is not purely declarative at plan time.

---

## Fix

Replaced `kubernetes_manifest` with a `null_resource` using `local-exec` to apply the manifest via `kubectl` after a deliberate wait:

```hcl
resource "time_sleep" "argocd_crds" {
  depends_on      = [helm_release.argocd]
  create_duration = "30s"
}

resource "null_resource" "root_app" {
  depends_on = [time_sleep.argocd_crds]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      ...
      EOF
    EOT
  }
}
```

The `time_sleep` gives ArgoCD CRDs time to register after Helm completes. The `local-exec` applies the manifest imperatively, bypassing plan-time validation.

---

## Lessons Learned

- `kubernetes_manifest` validates at plan time — it cannot create CRDs and consume them in the same run
- `null_resource` + `local-exec` is an escape hatch for situations where Terraform's declarative model cannot handle ordering
- This is a genuine Terraform limitation, not a user error
- Alternative approach: use a separate apply step for post-CRD resources

---

## Prevention

`time_sleep` duration set to 30 seconds — sufficient for ArgoCD CRDs to register. Documented in module with a comment explaining why `null_resource` is used instead of `kubernetes_manifest`.

