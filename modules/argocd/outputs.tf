output "argocd_namespace" {
  description = "Namespace ArgoCD is deployed in"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_helm_status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}
