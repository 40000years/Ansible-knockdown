# ============================================================================
# 📊 Dashboard Summary (ภาพรวมทั้งหมด)
# ============================================================================

output "summary_dashboard" {
  value = {
    "🖥️  EC2 Running Instances" = length(data.aws_instances.running.ids)
    "⏹️  EC2 Stopped Instances" = length(data.aws_instances.stopped.ids)
    "🌐  VPCs"                  = length(data.aws_vpcs.all.ids)
    "🔀  Subnets"               = length(data.aws_subnets.all.ids)
    "🛣️  Route Tables"          = length(data.aws_route_tables.all.ids)
    "🔒  Security Groups"       = length(data.aws_security_groups.all.ids)
    "💾  EBS Volumes"           = length(data.aws_ebs_volumes.all.ids)
    "📌  Elastic IPs"           = length(data.aws_eips.all.public_ips)
  }
  description = "สรุปภาพรวมของทรัพยากร AWS ทั้งหมดใน Account"
}

# ============================================================================
# 🖥️  EC2 Instances
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
# 🌐 VPC & Network
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
# 🔒 Security
# ============================================================================

output "security_group_details" {
  value       = local.security_group_summary
  description = "สรุปกฎ Security Groups: ชื่อ, VPC, Description"
}

# ============================================================================
# 💾 Storage & IPs
# ============================================================================

output "ebs_volume_ids" {
  value       = data.aws_ebs_volumes.all.ids
  description = "EBS Volume IDs ทั้งหมด"
}

output "elastic_ips" {
  value       = data.aws_eips.all.public_ips
  description = "Elastic IPs (EIP) ทั้งหมดที่จองไว้"
}
