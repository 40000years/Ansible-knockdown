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
# EC2 Stop Parameters
# ============================================================
variable "instance_ids" {
  type    = list(string)
  default = []
  # ถ้าปล่อย [] ว่างไว้ → ระบบจะ auto-discover เฉพาะ EC2 ที่ running อยู่จริงใน AWS
  # override เฉพาะตัวได้ใน Semaphore CLI args:
  # -var='instance_ids=["i-0ac9db71e7a4f2d52"]'
  description = "EC2 Instance IDs ที่ต้องการ Stop (ถ้าว่าง = auto-discover ทุกตัวที่ running)"
}

variable "nat_gateway_ids" {
  type    = list(string)
  default = []
  # override ด้วย: -var='nat_gateway_ids=["nat-0abc1234def56789a"]'
  description = "รายการ NAT Gateway IDs ที่ต้องลบก่อน Stop EC2 (ถ้าไม่มีให้ปล่อย [])"
}
