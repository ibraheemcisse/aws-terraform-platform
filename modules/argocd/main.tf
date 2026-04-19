resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_version
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.environment}.local"
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false
        }
      }
      repoServer = {
        replicas = var.environment == "prod" ? 2 : 1
      }
      applicationSet = {
        replicas = var.environment == "prod" ? 2 : 1
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

resource "time_sleep" "argocd_crds" {
  create_duration = "30s"
  depends_on      = [helm_release.argocd]
}

resource "null_resource" "root_app" {
  triggers = {
    repo_url        = var.repo_url
    target_revision = var.target_revision
    cluster_name    = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region us-east-1
      kubectl apply -f - <<EOF
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: root-app
        namespace: argocd
        finalizers:
          - resources-finalizer.argocd.argoproj.io
      spec:
        project: default
        source:
          repoURL: ${var.repo_url}
          targetRevision: ${var.target_revision}
          path: k8s/apps
        destination:
          server: https://kubernetes.default.svc
          namespace: argocd
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
      EOF
    EOT
  }

  depends_on = [time_sleep.argocd_crds]
}
