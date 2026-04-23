locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── CLOUDWATCH LOG GROUPS ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "host" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# ── POD IDENTITY TRUST POLICY ─────────────────────────────────────────
# WAF:Security — shared trust policy for all observability components
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

# ── POD IDENTITY ROLE FOR CLOUDWATCH AGENT ───────────────────────────
resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${var.cluster_name}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_pod_identity_association" "cloudwatch_agent" {
  cluster_name    = var.cluster_name
  namespace       = "amazon-cloudwatch"
  service_account = "cloudwatch-agent"
  role_arn        = aws_iam_role.cloudwatch_agent.arn
  tags            = local.common_tags
}

# ── POD IDENTITY ROLE FOR FLUENT BIT ─────────────────────────────────
resource "aws_iam_role" "fluent_bit" {
  name               = "${var.cluster_name}-fluent-bit-role"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "fluent_bit_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  name   = "${var.cluster_name}-fluent-bit-policy"
  role   = aws_iam_role.fluent_bit.id
  policy = data.aws_iam_policy_document.fluent_bit_policy.json
}

resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = var.cluster_name
  namespace       = "amazon-cloudwatch"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluent_bit.arn
  tags            = local.common_tags
}

# ── CLOUDWATCH ALARMS ─────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Node CPU above 80%"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Node memory above 80%"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "pod_restart_high" {
  alarm_name          = "${var.cluster_name}-pod-restarts-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Pod restart count above 5"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = local.common_tags
}
