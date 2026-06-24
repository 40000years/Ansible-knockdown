# ============================================================================
# Dashboard Summary (ภาพรวมทั้งหมด)
# ============================================================================

output "summary_dashboard" {
  value = {
    "EC2 Running Instances" = length(data.aws_instances.running.ids)
    "EC2 Stopped Instances" = length(data.aws_instances.stopped.ids)
    "VPCs"                  = length(data.aws_vpcs.all.ids)
    "Subnets"               = length(data.aws_subnets.all.ids)
    "Route Tables"          = length(data.aws_route_tables.all.ids)
    "Security Groups"       = length(data.aws_security_groups.all.ids)
    "EBS Volumes"           = length(data.aws_ebs_volumes.all.ids)
    "Elastic IPs"           = length(data.aws_eips.all.public_ips)
  }
  description = "สรุปภาพรวมของทรัพยากร AWS ทั้งหมดใน Account"
}

# ============================================================================
# EC2 Instances — Basic
# ============================================================================

output "ec2_running" {
  value       = local.running_instances
  description = "เครื่อง EC2 ที่กำลังทำงาน: Instance ID → IP Addresses"
}

output "ec2_stopped_ids" {
  value       = data.aws_instances.stopped.ids
  description = "Instance IDs ที่หยุดอยู่ (Stopped)"
}

# ============================================================================
# EC2 Instances — Advanced (OpenTofu-style Grouping)
# ============================================================================

output "ec2_running_detail" {
  value       = local.running_instances_detail
  description = "EC2 Running พร้อม Tags: Name, Environment, Role, Instance Type, AZ"
}

output "ec2_grouped_by_environment" {
  value       = local.ec2_grouped_by_environment
  description = "EC2 จัดกลุ่มตาม Tag 'Environment' → { instance_ids, private_ips, public_ips }"
}

# ============================================================================
# Ansible Dynamic Inventory (พร้อมใช้งาน)
# ============================================================================
# วิธีใช้: tofu output -json ansible_inventory_json > inventory.json
#          ansible -i inventory.json all -m ping

output "ansible_inventory_json" {
  value       = local.ansible_inventory
  description = "Ansible Dynamic Inventory (RFC format) — all hosts + hostvars + environment groups"
}

# ============================================================================
# VPC & Network — Basic
# ============================================================================

output "vpc_details" {
  value       = local.vpc_summary
  description = "รายละเอียด VPCs: CIDR Block, State, Is Default"
}

output "subnet_details" {
  value       = local.subnet_summary
  description = "รายละเอียด Subnets: AZ, CIDR, Available IPs, Is Public"
}

output "route_table_details" {
  value       = local.route_table_summary
  description = "รายละเอียด Route Tables: VPC, จำนวน Routes, จำนวน Associations"
}

# ============================================================================
# Network Topology (Advanced — Nested VPC → Subnets)
# ============================================================================

output "network_topology" {
  value       = local.network_topology
  description = "โครงสร้างเครือข่ายแบบ Nested: VPC → Subnets (CIDR, AZ, Public/Private)"
}

# ============================================================================
# Security
# ============================================================================

output "security_group_details" {
  value       = local.security_group_summary
  description = "สรุปกฎ Security Groups: ชื่อ, VPC, Description"
}

# ============================================================================
# Storage & IPs
# ============================================================================

output "ebs_volume_ids" {
  value       = data.aws_ebs_volumes.all.ids
  description = "EBS Volume IDs ทั้งหมด"
}

output "elastic_ips" {
  value       = data.aws_eips.all.public_ips
  description = "Elastic IPs (EIP) ทั้งหมดที่จองไว้"
}