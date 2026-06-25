# ============================================================
# AWS Credentials (ส่งมาจาก Semaphore Environment)
# ============================================================
variable "aws_region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS Region"
}

variable "AWS_DEFAULT_REGION" {
  type        = string
  default     = ""
  description = "AWS Region (Semaphore)"
}

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Access Key (Semaphore)"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Secret Key (Semaphore)"
}

# ============================================================
# EC2 Start Parameters
# ============================================================
variable "instance_ids" {
  type    = list(string)
  default = []
  # ถ้าปล่อยว่าง → auto-discover EC2 ที่ stopped อยู่ทั้งหมด
  # override เฉพาะตัว: -var='instance_ids=["i-0ac9db71e7a4f2d52"]'
  description = "EC2 Instance IDs ที่ต้องการ Start (ถ้าว่าง = auto-discover ทุกตัวที่ stopped)"
}

# ============================================================
# NAT Gateway Parameters (ต้องการเมื่อ create_nat_gateway = true)
# ============================================================
variable "create_nat_gateway" {
  type        = bool
  default     = true
  description = "สร้าง NAT Gateway ใหม่หลัง Start EC2 หรือไม่"
}

variable "nat_subnet_id" {
  type        = string
  default     = ""
  description = <<-EOT
    Public Subnet ID สำหรับสร้าง NAT Gateway ใหม่
    ต้องเป็น Public Subnet (มี Internet Gateway route)
    ตัวอย่าง: "subnet-065d2b96694fd9180"
  EOT
}

variable "eip_allocation_id" {
  type        = string
  default     = ""
  description = <<-EOT
    Elastic IP Allocation ID สำหรับ NAT Gateway ใหม่
    หา Allocation ID ได้จาก: aws ec2 describe-addresses --query 'Addresses[*].[PublicIp,AllocationId]'
    ตัวอย่าง: "eipalloc-0abc1234def56789a"
  EOT
}

variable "route_table_id" {
  type        = string
  default     = ""
  description = <<-EOT
    Route Table ID ที่ต้องการให้ 0.0.0.0/0 ชี้ไปที่ NAT GW ใหม่
    (Private Subnet Route Table ที่ EC2 ใช้งาน)
    ตัวอย่าง: "rtb-0a3011115ffd2126d"
  EOT
}
