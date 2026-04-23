locals {
  service_account_name = "aws-load-balancer-controller"
  namespace            = "kube-system"
}

# ── POD IDENTITY TRUST POLICY ─────────────────────────────────────────
# WAF:Security — Pod Identity replaces IRSA
# No OIDC provider reference — role is cluster-agnostic
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect  = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ── POD IDENTITY ROLE ─────────────────────────────────────────────────
resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

# ── ALB CONTROLLER IAM POLICY ─────────────────────────────────────────
data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = data.http.alb_policy.response_body
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ── POD IDENTITY ASSOCIATION ──────────────────────────────────────────
# Binds the role to the exact service account in kube-system
resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = var.cluster_name
  namespace       = local.namespace
  service_account = local.service_account_name
  role_arn        = aws_iam_role.alb_controller.arn
  tags            = var.tags
}

# ── HELM RELEASE ──────────────────────────────────────────────────────
# WAF:OpEx — controller installed as code, version pinned, reproducible
# Note: removed serviceAccount.annotations.eks.amazonaws.com/role-arn
# Pod Identity does not use service account annotations
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = local.namespace
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = local.service_account_name
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "region"
    value = "us-east-1"
  }

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller,
    aws_eks_pod_identity_association.alb_controller
  ]
}
