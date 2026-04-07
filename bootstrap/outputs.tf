output "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_lock_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tf_lock.name
}
