# PM-013 — GitHub Actions Path Filter Blocking Trigger

**Date:** April 2026  
**Severity:** Low — workflow not triggering  
**Status:** Resolved  

---

## Summary

After reconciling Terraform state locally, a git push was made to trigger the GitHub Actions workflow. The workflow did not trigger. The push appeared successful but no run appeared in the Actions tab.

---

## Root Cause

The `tf-apply.yml` workflow is configured with a `paths` filter:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'envs/**'
      - 'modules/**'
```

The commit used to trigger the workflow was an empty commit (`git commit --allow-empty`). Empty commits do not touch any files — the `paths` filter correctly determined that no relevant files changed and suppressed the workflow trigger.

---

## Fix

Used `workflow_dispatch` — the manual trigger already defined in the workflow:

```bash
gh workflow run "Terraform Apply" \
  --repo ibraheemcisse/aws-terraform-platform
```

Then approved the environment gate in the GitHub UI. Workflow ran successfully.

---

## Lessons Learned

- `paths` filters are additive to branch filters — both must match for a push trigger
- Empty commits bypass path filters by design
- `workflow_dispatch` is the correct tool for manual pipeline runs
- Always include `workflow_dispatch` in workflows that might need manual triggering

---

## Prevention

`workflow_dispatch` is already present in both workflow files. Use it for any manual trigger needs.

