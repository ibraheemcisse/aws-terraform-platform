variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "dev, staging, or prod"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS module"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from EKS module"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — passed to the Helm chart"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
