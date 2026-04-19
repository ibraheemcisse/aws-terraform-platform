# AWS EKS Platform — Terraform + GitOps

A production-grade EKS platform on AWS, provisioned entirely as code, delivering a containerised API via GitOps, with structured observability and automated CI/CD.

**Live endpoint:** `http://k8s-healthca-healthca-0f7ebab378-501580589.us-east-1.elb.amazonaws.com`

---

## Architecture

```
                          ┌─────────────────────────────────────────┐
                          │           GitHub Repository              │
                          │                                          │
                          │  Terraform modules    K8s manifests      │
                          │  ├── bootstrap/       ├── k8s/apps/      │
                          │  ├── modules/         └── k8s/healthcare/│
                          │  └── envs/dev/                           │
                          └────────────┬─────────────────┬───────────┘
                                       │                 │
                                       ▼                 ▼
                             GitHub Actions           ArgoCD
                             (infrastructure)         (workloads)
                             OIDC → AWS IAM           pull-based sync
                                       │                 │
                                       ▼                 ▼
                          ┌────────────────────────────────────────┐
                          │            AWS EKS Cluster             │
                          │            evershop-dev (1.30)         │
                          │                                        │
                          │  ┌─────────────────────────────────┐  │
                          │  │  kube-system                    │  │
                          │  │  ├── aws-load-balancer-controller│  │
                          │  │  ├── aws-ebs-csi-driver          │  │
                          │  │  ├── coredns                     │  │
                          │  │  └── fluent-bit + cw-agent       │  │
                          │  └─────────────────────────────────┘  │
                          │  ┌─────────────────────────────────┐  │
                          │  │  healthcare                      │  │
                          │  │  ├── healthcare-api (2 replicas) │  │
                          │  │  └── postgres (StatefulSet)      │  │
                          │  └─────────────────────────────────┘  │
                          └────────────┬───────────────────────────┘
                                       │
                          ┌────────────▼───────────────────────────┐
                          │         AWS Application Load Balancer   │
                          │         internet-facing, IP mode        │
                          └────────────────────────────────────────┘
                                       │
                                    Internet
```

---

## Stack

| Layer | Technology |
|-------|-----------|
| Cloud | AWS (us-east-1) |
| Kubernetes | EKS 1.30 |
| IaC | Terraform >= 1.5.0 |
| GitOps | ArgoCD 6.7.3 |
| Ingress | AWS Load Balancer Controller 1.7.1 |
| Storage | EBS CSI Driver (gp2) |
| Observability | CloudWatch Container Insights + Fluent Bit |
| CI/CD | GitHub Actions (OIDC) |
| Remote state | S3 + DynamoDB |
| Application | FastAPI Healthcare API + PostgreSQL 15 |

---

## Repository Structure

```
aws-terraform-platform/
├── bootstrap/                  # One-time state backend setup
│   ├── main.tf                 # S3 bucket + DynamoDB lock table
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   ├── networking/             # VPC, subnets, NAT, IGW, route tables
│   ├── eks/                    # Cluster, node groups, OIDC, addons, IRSA
│   ├── alb-controller/         # AWS Load Balancer Controller via Helm
│   ├── argocd/                 # ArgoCD via Helm + app-of-apps
│   └── observability/          # CloudWatch agent, Fluent Bit, alarms
├── envs/
│   ├── dev/                    # Dev environment root module
│   ├── staging/                # Staging backend config (ready)
│   └── prod/                   # Prod backend config (ready)
├── k8s/
│   ├── apps/                   # ArgoCD Application manifests
│   └── healthcare/             # Healthcare API K8s manifests
├── .github/
│   └── workflows/
│       ├── tf-plan.yml         # terraform plan on PR
│       └── tf-apply.yml        # terraform apply on push (approval gate)
└── postmortems/                # Incident documentation
```

---

## Modules

### bootstrap

Creates the S3 bucket and DynamoDB table that all Terraform state depends on. Run once manually with local state — the bootstrap problem solved correctly.

```
S3 bucket:      aws-terraform-platform-tfstate-{account_id}
DynamoDB table: terraform-state-lock
Encryption:     aws:kms
Versioning:     enabled
Public access:  blocked
```

```bash
cd bootstrap
terraform init
terraform apply -var="account_id=YOUR_ACCOUNT_ID"
```

### modules/networking

VPC foundation. Multi-AZ design with public and private subnets. Includes the Kubernetes subnet tags that the ALB controller requires to discover subnets.

| Resource | Value |
|----------|-------|
| VPC CIDR | 10.0.0.0/16 |
| Public subnets | 10.0.1.0/24, 10.0.2.0/24 (us-east-1a, 1b) |
| Private subnets | 10.0.10.0/24, 10.0.11.0/24 (us-east-1a, 1b) |
| NAT Gateways | One per AZ |
| Tags | `kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb` |

**WAF:Security** — nodes in private subnets, not directly internet-reachable.
**WAF:Reliability** — multi-AZ, NAT per AZ, no single point of failure.

### modules/eks

EKS cluster with managed node groups in private subnets. OIDC provider is the foundation of IRSA — all pod-level AWS access flows through it.

| Resource | Value |
|----------|-------|
| Cluster | evershop-dev (Kubernetes 1.30) |
| Nodes | t3.small, private subnets, multi-AZ |
| Add-ons | CoreDNS, kube-proxy, vpc-cni, aws-ebs-csi-driver |
| IRSA roles | 5 scoped roles (see below) |

**IRSA roles provisioned:**

| Role | Service Account | Purpose |
|------|----------------|---------|
| evershop-dev-ebs-csi-role | ebs-csi-controller-sa | Provision EBS volumes |
| evershop-dev-ecr-pull-role | healthcare-api-sa | Pull images from ECR |
| evershop-dev-alb-controller-role | aws-load-balancer-controller | Manage ALBs |
| evershop-dev-cloudwatch-agent-role | cloudwatch-agent | Write metrics |
| evershop-dev-fluent-bit-role | fluent-bit | Write logs |

Each role is scoped with OIDC conditions on both `:sub` (service account) and `:aud` (STS) — least privilege, no wildcards.

**WAF:Security** — pod-level IAM via IRSA, not node-level access.

### modules/alb-controller

AWS Load Balancer Controller installed via Helm. Watches Ingress resources and provisions AWS ALBs automatically. Uses IP target type — traffic goes directly to pod IPs, bypassing NodePort.

```hcl
chart   = "aws-load-balancer-controller"
version = "1.7.1"
mode    = "IP target type"
```

**WAF:Performance** — IP mode eliminates the NodePort hop, reducing latency.

### modules/argocd

GitOps delivery layer. ArgoCD installed via Helm with the app-of-apps pattern. Any Application manifest added to `k8s/apps/` is automatically picked up and deployed.

```
Pattern:   app-of-apps
Repo:      github.com/ibraheemcisse/aws-terraform-platform
Path:      k8s/apps/
Sync:      automated, prune=true, selfHeal=true
```

`selfHeal: true` means any manual `kubectl` change is automatically reverted. Git is always the source of truth.

**WAF:Reliability** — drift detection and auto-correction without manual intervention.
**WAF:OpEx** — zero manual deployments, full audit trail via git history.

### modules/observability

CloudWatch Container Insights with two components: CloudWatch Agent for metrics and Fluent Bit for log shipping. Both run as DaemonSets with IRSA roles.

**Log groups:**
```
/aws/containerinsights/evershop-dev/application  ← container logs
/aws/containerinsights/evershop-dev/performance  ← node/pod metrics
/aws/containerinsights/evershop-dev/host         ← node system logs
/aws/containerinsights/evershop-dev/dataplane    ← control plane logs
```

**CloudWatch Alarms:**
```
evershop-dev-node-cpu-high      → >80% CPU
evershop-dev-node-memory-high   → >80% memory
evershop-dev-pod-restarts-high  → >5 restarts in 5 minutes
```

Retention: 7 days (cost-optimised for non-production).

---

## Remote State

State is isolated per environment using separate S3 key paths and a shared DynamoDB lock table.

```
S3 bucket: aws-terraform-platform-tfstate-406260455716
├── dev/terraform.tfstate
├── staging/terraform.tfstate
└── prod/terraform.tfstate

DynamoDB: terraform-state-lock (shared, LockID per key)
```

State locking prevents concurrent applies. If a process is killed mid-apply, run `terraform force-unlock <LOCK_ID>` after confirming no other apply is running.

---

## CI/CD Pipeline

### Authentication

GitHub Actions authenticates to AWS via OIDC — no static access keys stored anywhere.

```
OIDC provider: token.actions.githubusercontent.com
Role:          github-actions-terraform-role
Trust:         repo:ibraheemcisse/aws-terraform-platform:*
```

### Workflows

| Workflow | Trigger | Steps |
|----------|---------|-------|
| tf-plan.yml | PR to main (envs/** or modules/**) | init → validate → plan → post to PR |
| tf-apply.yml | Push to main (envs/** or modules/**) | init → apply (requires approval) |

### Environment Protection

The `dev` GitHub environment requires manual approval before every `terraform apply`. Approval history is recorded in the GitHub deployment log — full audit trail.

---

## Quickstart

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- kubectl
- helm

### 1. Bootstrap the state backend (once)

```bash
cd bootstrap
terraform init
terraform apply -var="account_id=YOUR_ACCOUNT_ID"
```

### 2. Deploy the dev environment

```bash
cd envs/dev
terraform init
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name evershop-dev
```

### 4. Verify

```bash
kubectl get nodes
kubectl get all -n healthcare
kubectl get applications -n argocd
```

### Destroy (cost management)

```bash
cd envs/dev
terraform destroy -auto-approve
# Bootstrap resources (S3 + DynamoDB) intentionally excluded
```

---

## The Application

### Healthcare API (FastAPI + PostgreSQL)

A production-grade REST API deployed as the platform workload. Chosen over EverShop due to build complexity — the right engineering call documented in [PM-003](#postmortems).

**Endpoints:**
```
POST   /patients              → create patient
GET    /patients              → list all patients
GET    /patients/{id}         → get patient by UUID
POST   /appointments          → schedule appointment
GET    /doctors/{id}/schedule → get doctor schedule
GET    /health                → health check (ALB + probes)
```

**Structured logging** — every request emits JSON to stdout, enriched by Fluent Bit and shipped to CloudWatch:
```json
{
  "levelname": "INFO",
  "message": "request",
  "method": "GET",
  "path": "/health",
  "status": 200,
  "duration_ms": 0.46
}
```

---

## Well-Architected Framework

Every architectural decision maps to a WAF pillar. This table is the reasoning made explicit.

| Pillar | Decision | Implementation |
|--------|----------|----------------|
| Security | Pod-level IAM | IRSA — 5 scoped roles, no node-level access |
| Security | No static credentials | OIDC for GitHub Actions + IRSA for pods |
| Security | Private compute | EKS nodes in private subnets only |
| Security | Image registry | ECR with IRSA pull — no public registry |
| Reliability | Multi-AZ | Subnets + NAT gateways across us-east-1a/b |
| Reliability | API redundancy | 2 replicas, health probes, rolling updates |
| Reliability | Drift detection | ArgoCD selfHeal — reverts manual changes |
| Reliability | Persistent storage | EBS CSI — data survives pod restarts |
| Operational Excellence | Everything as code | Terraform + K8s manifests, zero console changes |
| Operational Excellence | GitOps delivery | ArgoCD — git is the source of truth |
| Operational Excellence | Approval gates | Manual review on every terraform apply |
| Operational Excellence | Audit trail | GitHub Actions deployment history |
| Operational Excellence | Structured logs | JSON logs queryable in CloudWatch Insights |
| Performance Efficiency | Direct pod routing | IP mode ALB — no NodePort hop |
| Performance Efficiency | Right-sized compute | t3.small dev / t3.medium prod via tfvars |
| Performance Efficiency | Fast storage | EBS gp2 for PostgreSQL |
| Cost Optimization | Minimal compute | t3.small nodes, min_size=1 in dev |
| Cost Optimization | On-demand billing | PAY_PER_REQUEST DynamoDB |
| Cost Optimization | Log retention | 7 days in dev (not indefinite) |
| Cost Optimization | Destroy workflow | Full teardown between sessions |

---

## Postmortems

Real incidents encountered and resolved during the build. Documented here because problems are more instructive than clean runs.

| ID | Symptom | Root Cause | Fix |
|----|---------|------------|-----|
| PM-001 | Node group CREATE_FAILED | Kubernetes 1.29 incompatibility | Upgraded to 1.30 |
| PM-002 | t3.medium quota exceeded | Free tier constraint | Changed to t3.small |
| PM-003 | EBS CSI addon timeout (20min) | No IRSA role — fell back to IMDS on private subnet | Added IRSA role with scoped trust policy |
| PM-004 | EverShop build failures | Missing dirs, musl vs glibc, wrong Node version | Switched to Healthcare API |
| PM-005 | Postgres CrashLoopBackOff | EBS volume has lost+found, postgres init fails | Added PGDATA env var pointing to subdirectory |
| PM-006 | PVC stuck terminating | Pod still holding volume reference | Patched finalizers, force deleted |
| PM-007 | ArgoCD CRD race condition | kubernetes_manifest validated at plan time before CRDs exist | null_resource + time_sleep + local-exec |
| PM-008 | Fluent Bit CreateContainerConfigError | Missing fluent-bit-cluster-info ConfigMap | Created ConfigMap, now in manifests |
| PM-009 | GitHub Actions EKS auth failure | Role not mapped in EKS RBAC | EKS access entries + token-based provider |
| PM-010 | Node pod limit hit | t3.small hard limit of 11 pods per node | Scaled to 3 nodes |
| PM-011 | DNS flapping to EKS endpoint | Local resolver issue | Added static entry to /etc/hosts |
| PM-012 | ArgoCD reverting image tags | ArgoCD out of sync, overwriting manual patches | Force refresh + pinned image tags in Git |
| PM-013 | GitHub Actions path filter | Empty commit didn't trigger workflow | Used workflow_dispatch for manual trigger |

Full postmortem writeups in [`postmortems/`](./postmortems/).

---

## Related Content

- **Blog post 1:** Remote Terraform state with S3 + DynamoDB locking
- **Blog post 2:** Reusable Terraform modules for multi-environment EKS
- **Blog post 3:** End-to-end CI/CD on EKS — GitHub Actions + ArgoCD
- **Blog post 4:** AWS Well-Architected Framework mapped to a real EKS platform
- **YouTube:** Full walkthrough playlist

---

## Author

**Ibrahim Cisse** — Infrastructure & SRE Engineer  
AWS Community Builder (Containers) · Founder, Cloud Native Community Group Kuala Lumpur  
Organiser, KCD Kuala Lumpur 2026

[LinkedIn](https://linkedin.com/in/ibraheemcisse) · [GitHub](https://github.com/ibraheemcisse) · [Medium](https://medium.com/@ibraheemcisse)

---

*Built on AWS · Provisioned with Terraform · Delivered by ArgoCD · Observed with CloudWatch*
