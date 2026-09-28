# -------------------------------------------------------
# GitHub Actions OIDC — keyless authentication to AWS
# -------------------------------------------------------
# WAF:Security — no static access keys stored in GitHub.
# GitHub's OIDC token is exchanged for short-lived AWS
# credentials scoped to this role on every workflow run.

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable, published by GitHub)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Project   = "aws-terraform-platform"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Scope trust to this repo only — any ref (branch, tag, PR)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = {
    Project   = "aws-terraform-platform"
    ManagedBy = "terraform"
  }
}

# AdministratorAccess — GitHub Actions needs to provision the full
# platform (VPC, EKS, IAM roles, Helm releases, etc.).
# Scope this down once the platform is stable.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
