variable "aws_region" {
  description = "AWS region to deploy bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID — used to ensure globally unique S3 bucket name"
  type        = string
}
