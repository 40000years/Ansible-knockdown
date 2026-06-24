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
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "ec2-fetch/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "your-terraform-lock-table" # ตัวเลือกเพิ่มเติมสำหรับ State Locking
  # }
}

provider "aws" {
  region = var.aws_region
}
