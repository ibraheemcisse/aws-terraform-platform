# PM-004 — EverShop Build Failures

**Date:** April 2026  
**Severity:** Medium — blocked application deployment  
**Status:** Resolved by workload substitution  

---

## Summary

EverShop (a TypeScript e-commerce platform) was the original planned workload for the platform demo. After six Docker image build attempts across versions v1.2.2 through v1.2.6, the application could not be deployed successfully. The decision was made to substitute with the Healthcare API — an application we owned and controlled.

---

## Issues Encountered

```
1. Missing build artifacts — npm build output not included in image
2. Wrong Node.js version — Alpine musl libc vs glibc native module conflicts
3. Missing config directory — app expected /app/config at runtime
4. Wrong environment variable names — DB_HOST vs DATABASE_URL mismatch
5. PostgreSQL connection string format — EverShop expected specific format
6. Init sequence complexity — Redis + PostgreSQL + migration dependencies
```

---

## Root Cause

EverShop is a complex application with a multi-step build chain designed for development environments. The Dockerfile required significant customisation to produce a working production image. Each fix exposed the next issue, creating a compounding debugging loop.

---

## Decision

After six image versions and no successful deployment, the engineering decision was made to cut losses. The platform — EKS, Terraform, ArgoCD, IRSA, ALB, observability — is the portfolio piece, not the application. A working demo with a simple app is more valuable than a broken demo with a complex one.

**Switched to:** Healthcare API (FastAPI + PostgreSQL) — deployed successfully on the first attempt.

---

## Lessons Learned

- For platform demos, own the application — don't depend on third-party apps you cannot modify
- The workload is a vehicle for demonstrating the platform, not the point of the portfolio
- Sunk cost is real — knowing when to cut and move on is an engineering skill

