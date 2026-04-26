# Ibrahim Cisse
**Infrastructure & SRE Engineer**

Kuala Lumpur, Malaysia · [ibrahimcisse@ioc-labs.com](mailto:ibrahimcisse@ioc-labs.com) · [LinkedIn](https://linkedin.com/in/ibraheemcisse) · [GitHub](https://github.com/ibraheemcisse) · [ioc-labs.com](https://ioc-labs.com)

---

## What I Do

I find hidden failures in production Kubernetes clusters before they become incidents.

4 years operating infrastructure for fintech systems where downtime has direct financial impact cryptocurrency exchanges and global forex trading platforms. I build the platform, document every failure, and write about both.

- Resolved a cluster-wide failure affecting live trade execution in under 1 hour
- Identified a silent CI/CD pipeline failure across 12 production servers, reduced deployment failures by 83%
- Cut incident investigation time from 2 hours to 15 minutes in a live forex environment
- Caught an EBS CSI CrashLoopBackOff after a Pod Identity migration. 11 restarts, no alert fired

---

## Experience

### Devops Engineer
**Bespoke Labs** · Contract · Remote · Feb 2026 – Present

Designing adversarial Kubernetes evaluation environments for LLM agents on the Nebula Aurora platform.

- Provisioned and hardened Kubernetes environments RBAC, secret management, Istio service mesh, ingress access control
- Engineered configuration drift mechanisms using CronJobs and scoped service accounts
- Replaced nginx ingress with Istio AuthorizationPolicy for mTLS and workload identity validation
- Maintained evaluation infrastructure across multiple concurrent LLM agent rollouts

---

### Infrastructure Operations Engineer L3 — SRE
**Shift Markets** · Remote · Jul 2024 – Apr 2026

Cryptocurrency exchange infrastructure — high-availability trading platform across 20+ production environments.

- Resolved cluster-wide failure impacting live trade execution in under 1 hour postmortem adopted as team standard
- Identified silent CI/CD pipeline reporting success while failing — eliminated invisible failure class across 12 servers, reduced deployment failures by 83%
- Built AI-assisted PR review pipeline (Claude API + GitHub Actions) benchmarked against commercial tooling
- Managed Terraform IaC across 20+ production exchange environments — zero static credentials
- Maintained observability across Prometheus, Grafana, and CloudWatch

---

### Trading Infrastructure Support Engineer L2
**Exness** · Kuala Lumpur · Mar 2023 – Feb 2024

Global forex platform — 24/7 infrastructure supporting millions of active traders.

- Cut incident investigation time from 2 hours to 15 minutes, built ClickHouse SQL tooling enabling L1 resolution without escalation
- On-call 3x/week — triaged incidents using Prometheus, Grafana, Datadog, PagerDuty
- Led zero-downtime migration of thousands of live accounts — no user-facing incidents
- Eliminated single-operator dependency on critical market data pipeline — automated, documented, mentored 3 engineers

---

### Customer Service Executive
**Exness** · Kuala Lumpur · Mar 2022 – Mar 2023

Promoted to infrastructure operations after one year based on consistent KPI performance and technical escalation quality.

---

### Cybersecurity Consultant
**Condition Zebra** · Kuala Lumpur · Sep 2021 – Mar 2022

Advised enterprise clients including IOI Group and Knight Frank Malaysia on MDR, EDR, XDR, and DFIR. Delivered security awareness programs across five Malaysian universities.

---

## Projects

### AWS EKS Platform — Terraform + GitOps
[github.com/ibraheemcisse/aws-terraform-platform](https://github.com/ibraheemcisse/aws-terraform-platform)

Production-grade EKS platform on AWS — VPC, EKS 1.30, Pod Identity across 5 IAM roles, ArgoCD GitOps, GitHub Actions OIDC CI/CD, CloudWatch observability across dev/staging/prod. 15 production incidents documented with root cause analysis. Every decision mapped to the AWS Well-Architected Framework.

### Bare Metal Kubernetes — Failure Simulation
[github.com/ibraheemcisse/infrastructure-lab](https://github.com/ibraheemcisse/infrastructure-lab)

Kubernetes on Hetzner/Proxmox via Kubespray. Simulated node loss, OOM kills, StatefulSet failures. Uncovered critical storage SPOF. Published blameless postmortems on Medium and GitHub.

### Financial Transaction Processing Microservice
[github.com/ibraheemcisse/forage-midas](https://github.com/ibraheemcisse/forage-midas)

Java 17, Spring Boot, Apache Kafka, Maven. Built as part of the JPMorgan Chase Advanced Software Engineering program. Kafka consumer, JPA persistence, validation layer, REST API.

---

## Technical Skills

| Category | Tools |
|----------|-------|
| Cloud | AWS (EKS, EC2, S3, IAM, VPC, ALB, CloudWatch, ECR), Azure |
| IaC | Terraform, Ansible, Helm |
| Containers | Kubernetes (CKA), Docker, Istio, k3s |
| CI/CD | GitHub Actions, ArgoCD, GitLab CI, TeamCity |
| Observability | Prometheus, Grafana, CloudWatch, Datadog, PagerDuty, Loki |
| Languages | Python, Bash, Java |
| Databases | PostgreSQL, ClickHouse, Redis |
| Networking | TCP/IP, TLS, DNS, VPC, RBAC |

---

## Certifications

- AWS Solutions Architect Associate — SAA-C03 *(in progress)*
- Microsoft Azure Fundamentals — AZ-900
- Prometheus Monitoring & Alerting
- Google IT Support Professional
- McKinsey Forward Program *(completing May 2026)*

---

## Education

**BEng Electronic & Communication Engineering (Hons)**
Anglia Ruskin University, 2019

---

## Community

- **AWS Community Builder** — Containers category
- **CNCF KL Chapter member, KCD Kuala Lumpur 2026** — Malaysia's first Kubernetes Community Days, 250+ expected attendees
- **157+ published articles** — Medium, AWS CB Blog, Dev.to, Hashnode

---

## Writing

Selected recent posts:

- [Every decision I made building this EKS platform, mapped to the AWS Well-Architected Framework](https://medium.com/@Ibraheemcisse)
- [I migrated from IRSA to Pod Identity — here's what changed in the Terraform](https://medium.com/@Ibraheemcisse)
- [My cluster looked healthy. It wasn't.](https://medium.com/@Ibraheemcisse)

---

*Open to full-time and contract SRE / DevOps / Platform Engineering roles. Remote or relocation.*
*Available for EKS debugging and consulting engagements at [ioc-labs.com](https://ioc-labs.com)*
