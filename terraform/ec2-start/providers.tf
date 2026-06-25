# Compatible with: OpenTofu >= 1.6.x
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  # State แยกจาก stop workspace
  backend "s3" {
    bucket = "thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an"
    key    = "ec2-power/start/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region     = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region
  access_key = var.AWS_ACCESS_KEY_ID != "" ? var.AWS_ACCESS_KEY_ID : null
  secret_key = var.AWS_SECRET_ACCESS_KEY != "" ? var.AWS_SECRET_ACCESS_KEY : null
}

provider "null" {}
