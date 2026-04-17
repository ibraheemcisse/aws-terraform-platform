output "irsa_role_arn" {
  description = "IRSA role ARN for the ALB controller"
  value       = aws_iam_role.alb_controller.arn
}

output "helm_release_status" {
  description = "Status of the ALB controller Helm release"
  value       = helm_release.alb_controller.status
}
