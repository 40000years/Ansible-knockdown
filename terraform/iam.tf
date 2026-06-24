# ============================================================================
# IAM Policy สำหรับ Terraform EC2 Read-Only Access
# ============================================================================
# ไฟล์นี้สร้าง IAM Policy และผูกเข้ากับ User "Ansible"
# เพื่อให้ Terraform มีสิทธิ์ดึงข้อมูล AWS ทุก Resource แบบ Read-Only
# ============================================================================

# สร้าง IAM Policy Document ที่อนุญาตสิทธิ์อ่านข้อมูล EC2/VPC ทั้งหมด
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
}

# สร้าง IAM Policy จาก Document ด้านบน
resource "aws_iam_policy" "terraform_readonly" {
  name        = "TerraformEC2ReadOnly"
  description = "Read-only access to EC2/VPC resources for Terraform"
  policy      = data.aws_iam_policy_document.terraform_readonly.json

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 Resource Inventory"
  }
}

# ผูก Policy เข้ากับ IAM User "Ansible" ที่ Semaphore ใช้งาน
resource "aws_iam_user_policy_attachment" "ansible_readonly" {
  user       = "Ansible"
  policy_arn = aws_iam_policy.terraform_readonly.arn
}
