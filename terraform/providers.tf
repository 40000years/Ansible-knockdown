terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # -----------------------------------------------------------------------------
  # S3 Backend: แนะนำให้เปิดใช้งานสำหรับ Semaphore เพื่อป้องกันไฟล์ state สูญหาย
  # -----------------------------------------------------------------------------
  backend "s3" {
    bucket         = "thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an"
    key            = "ec2-fetch/terraform.tfstate"
    region         = "ap-southeast-1"
    # dynamodb_table = "your-terraform-lock-table" # เปิดใช้งานหากมี DynamoDB Table สำหรับ Lock State
  }
}

provider "aws" {
  # ใช้ค่าภูมิภาค (Region) จาก Semaphore หากส่งมา หากไม่มีให้ใช้ค่าเริ่มต้นใน variables.tf
  region     = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region
  access_key = var.AWS_ACCESS_KEY_ID != "" ? var.AWS_ACCESS_KEY_ID : null
  secret_key = var.AWS_SECRET_ACCESS_KEY != "" ? var.AWS_SECRET_ACCESS_KEY : null
}
