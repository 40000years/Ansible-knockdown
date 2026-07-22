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

variable "k3s_master_id" {
  type        = string
  default     = ""
  description = "k3s_master_id (ส่งผ่านมาจาก Semaphore สำหรับ Ansible แต่ Terraform รับมาด้วย)"
}

variable "zabbix_server_ip" {
  type        = string
  default     = ""
  description = "zabbix_server_ip (ส่งผ่านมาจาก Semaphore สำหรับ Ansible)"
}

variable "prometheus_server_ip" {
  type        = string
  default     = ""
  description = "prometheus_server_ip (ส่งผ่านมาจาก Semaphore สำหรับ Ansible)"
}

variable "k3s_master_ip" {
  type        = string
  default     = ""
  description = "k3s_master_ip (ส่งผ่านมาจาก Semaphore สำหรับ Ansible)"
}

variable "k3s_token" {
  type        = string
  default     = ""
  description = "k3s_token (ส่งผ่านมาจาก Semaphore สำหรับ Ansible)"
}
