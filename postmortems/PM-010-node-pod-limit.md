# PM-010 — Node Pod Limit on t3.small

**Date:** April 2026  
**Severity:** Medium — workload scheduling failures  
**Status:** Resolved  

---

## Summary

Pods entered `Pending` state with the reason `Too many pods` despite nodes appearing healthy. The cluster had available CPU and memory but could not schedule additional pods.

---

## Error

```
Warning  FailedScheduling  pod/fluent-bit-xxxxx
0/2 nodes are available: 2 Too many pods.
```

---

## Root Cause

AWS EC2 instance types have a hard limit on the number of pods per node, determined by the number of elastic network interfaces (ENIs) and secondary IP addresses the instance supports. For `t3.small`:

```
Max ENIs:              3
IPv4 addresses per ENI: 4
Max pods formula:      (ENIs × (addresses - 1)) + 2 = 11
t3.small max pods:     11
```

With `kube-system` system pods consuming 7-8 pods per node, only 3-4 slots remain for workloads per node. With 2 nodes, the cluster could support approximately 6-8 workload pods — insufficient for the full stack.

---

## Fix

Scaled from 2 to 3 nodes:

```hcl
# envs/dev/terraform.tfvars
node_desired_size = 3
node_max_size     = 4
```

Three nodes × 11 pods = 33 total pod capacity. With ~8 system pods per node, ~9 workload pods available — sufficient for the full stack.

---

## Lessons Learned

- Always calculate pod capacity before cluster deployment: `(ENIs × (IPs - 1)) + 2`
- t3.small is borderline for a full platform stack — t3.medium (17 pods) is more comfortable
- The VPC CNI plugin's pod density is a real constraint, not a theoretical one

---

## Reference

AWS ENI limits by instance type:
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html

