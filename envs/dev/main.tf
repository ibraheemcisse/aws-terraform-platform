locals {
  common_tags = {
    Project     = "aws-terraform-platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "networking" {
  source = "../../modules/networking"

  cluster_name         = var.cluster_name
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  azs                  = ["us-east-1a", "us-east-1b"]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  cluster_version     = "1.31"
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  node_instance_types = ["t3.small"]
  node_desired_size   = 4
  node_min_size       = 1
  node_max_size       = 4
  node_disk_size      = 20
  tags                = local.common_tags
}

module "alb_controller" {
  source = "../../modules/alb-controller"

  cluster_name = module.eks.cluster_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  tags         = local.common_tags
}

# Wait for ALB controller webhook pod to become ready before ArgoCD
# creates Service resources that trigger the mutating webhook.
resource "time_sleep" "alb_controller_ready" {
  create_duration = "90s"
  depends_on      = [module.alb_controller]
}

module "argocd" {
  source = "../../modules/argocd"

  cluster_name    = module.eks.cluster_name
  environment     = var.environment
  repo_url        = "https://github.com/ibraheemcisse/aws-terraform-platform"
  target_revision = "main"
  tags            = local.common_tags

  depends_on = [time_sleep.alb_controller_ready]
}

module "observability" {
  source = "../../modules/observability"

  cluster_name       = module.eks.cluster_name
  environment        = var.environment
  log_retention_days = 7
  tags               = local.common_tags
}
