
data "aws_iam_policy_document" "terraform_readonly" {
  statement {
    sid    = "EC2ReadOnly"
    effect = "Allow"
    actions = [
      # EC2 Instances
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceCreditSpecifications",
      # VPC & Networking
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      # Security
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      # Storage
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeSnapshots",
      # IPs & DNS
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      # Tags & Misc
      "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeKeyPairs",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3StateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [
      "arn:aws:s3:::thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an",
      "arn:aws:s3:::thanaphat-web-app-bucket-2026-858039354188-ap-southeast-1-an/*",
    ]
  }

  # ============================================================
  # สิทธิ์สำหรับ HTML Dashboard (S3 Bucket + CloudFront)
  # เพิ่มประสิทธิภาพ IAM Policy นี้ให้ User Ansible เพื่อให้ terraform apply
  # สร้างและจัดการ S3 Bucket และ CloudFront Distribution ได้อัตโนมัติ
  # (บีบอัดโค้ดโดยใช้ Wildcard เพื่อแก้ปัญหาเรื่องความยาวเกิน 2048 ตัวอักษร)
  # ============================================================

  statement {
    sid    = "S3DashboardBucketManagement"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::aws-infra-dashboard-858039354188-ap-southeast-1",
      "arn:aws:s3:::aws-infra-dashboard-858039354188-ap-southeast-1/*",
    ]
  }

  statement {
    sid    = "CloudFrontDashboardManagement"
    effect = "Allow"
    actions = [
      "cloudfront:*"
    ]
    resources = ["*"]
  }
}

# ============================================================================
# หมายเหตุ: นำคอมเมนต์ออก (Uncomment) ไม่ได้ เพราะ User 'Ansible' 
# ไม่มีสิทธิ์จัดการ IAM Policy (เพื่อความปลอดภัย)
# เราจะเก็บโค้ดส่วนนี้ไว้เป็น Document ให้อ่านอ้างอิงเท่านั้น
# การแก้ไขสิทธิ์ต้องไปทำที่ AWS Console โดยตรง
# ============================================================================

# resource "aws_iam_policy" "terraform_readonly" {
#   name        = "TerraformEC2ReadOnly"
#   description = "Read-only access to EC2/VPC resources for Terraform"
#   policy      = data.aws_iam_policy_document.terraform_readonly.json
# }
# 
# resource "aws_iam_user_policy_attachment" "ansible_readonly" {
#   user       = "Ansible"
#   policy_arn = aws_iam_policy.terraform_readonly.arn
# }
