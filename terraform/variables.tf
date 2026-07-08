
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

# ============================================================================
# Azure Variables
# ============================================================================

variable "azure_subscription_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Azure Subscription ID"
}

variable "azure_client_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Azure Service Principal Client ID (App ID)"
}

variable "azure_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Azure Service Principal Client Secret (Password)"
}

variable "azure_tenant_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Azure Tenant ID"
}

variable "azure_location" {
  type        = string
  default     = "southeastasia"
  description = "Azure Region / Location (e.g. southeastasia, eastus)"
}

variable "azure_resource_group" {
  type        = string
  default     = "radahn-rg"
  description = "Azure Resource Group Name"
}

variable "enable_azure" {
  type        = bool
  default     = false
  description = "Set to true to enable Azure resources provisioning"
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "Set to true to deploy Site-to-Site VPN between AWS and Azure (requires enable_azure=true)"
}
