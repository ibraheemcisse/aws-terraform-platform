variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "cluster_oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
