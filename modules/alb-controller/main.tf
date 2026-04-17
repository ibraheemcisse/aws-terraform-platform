locals {
  service_account_name = "aws-load-balancer-controller"
  namespace            = "kube-system"
}

# ── IRSA TRUST POLICY ─────────────────────────────────────────────────
# WAF:Security — scoped to the exact service account in kube-system
data "aws_iam_policy_document" "alb_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IRSA ROLE ─────────────────────────────────────────────────────────
resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_assume.json
  tags               = var.tags
}

# ── ALB CONTROLLER IAM POLICY ─────────────────────────────────────────
# Official AWS policy — permissions to manage ALBs, target groups,
# security groups, and WAF rules on behalf of Ingress resources
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

# ── HELM RELEASE ──────────────────────────────────────────────────────
# WAF:OpEx — controller installed as code, version pinned, reproducible
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

  # Wire the IRSA role to the service account annotation
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  depends_on = [aws_iam_role_policy_attachment.alb_controller]
}
