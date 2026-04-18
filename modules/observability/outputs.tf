output "cloudwatch_agent_role_arn" {
  description = "CloudWatch agent IRSA role ARN"
  value       = aws_iam_role.cloudwatch_agent.arn
}

output "fluent_bit_role_arn" {
  description = "Fluent Bit IRSA role ARN"
  value       = aws_iam_role.fluent_bit.arn
}

output "log_group_application" {
  description = "Application log group name"
  value       = aws_cloudwatch_log_group.application.name
}
