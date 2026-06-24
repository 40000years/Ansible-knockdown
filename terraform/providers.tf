terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an"
    key            = "ec2-fetch/terraform.tfstate"
    region         = "ap-southeast-1"
    # dynamodb_table = "your-terraform-lock-table" # เปิดใช้งานหากมี DynamoDB Table สำหรับ Lock State
  }
}

provider "aws" {
  region = var.aws_region
}
