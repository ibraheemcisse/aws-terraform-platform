output "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_lock_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tf_lock.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — paste into workflow ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
