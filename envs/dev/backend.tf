terraform {
  backend "s3" {
    bucket         = "aws-terraform-platform-tfstate-406260455716"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
