terraform {
  backend "s3" {
    bucket         = "aws-terraform-platform-tfstate-406260455716"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
