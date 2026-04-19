variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "dev, staging, or prod"
  type        = string
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "6.7.3"
}

variable "repo_url" {
  description = "GitHub repo ArgoCD will watch"
  type        = string
}

variable "target_revision" {
  description = "Branch ArgoCD watches"
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
