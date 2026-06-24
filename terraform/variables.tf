variable "aws_region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS Region ที่ต้องการดึงข้อมูล EC2 (ค่าเริ่มต้น)"
}

variable "AWS_DEFAULT_REGION" {
  type        = string
  default     = ""
  description = "AWS Default Region (ส่งผ่านมาจาก Semaphore)"
}

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Access Key ID (ส่งผ่านมาจาก Semaphore)"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Secret Access Key (ส่งผ่านมาจาก Semaphore)"
}
