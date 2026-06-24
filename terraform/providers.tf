# Compatible with: Terraform >= 1.5.0 AND OpenTofu >= 1.6.x
# Both tools share the same S3 state backend — do NOT run both simultaneously.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # S3 Backend: shared between Terraform and OpenTofu runs.
  # OpenTofu reads/writes the same terraform.tfstate file transparently.
  backend "s3" {
    bucket = "thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an"
    key    = "ec2-fetch/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region     = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region
  access_key = var.AWS_ACCESS_KEY_ID != "" ? var.AWS_ACCESS_KEY_ID : null
  secret_key = var.AWS_SECRET_ACCESS_KEY != "" ? var.AWS_SECRET_ACCESS_KEY : null
}
