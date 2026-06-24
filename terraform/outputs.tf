# ============================================================================
# 📊 สรุปภาพรวมทั้งหมด (Summary Dashboard)
# ============================================================================

output "summary_dashboard" {
  value = {
    "🖥️  EC2 Running Instances"   = length(data.aws_instances.running.ids)
    "⏹️  EC2 Stopped Instances"   = length(data.aws_instances.stopped.ids)
    "🌐  VPCs"                    = length(data.aws_vpcs.all.ids)
    "🔀  Subnets"                 = length(data.aws_subnets.all.ids)
    "🔒  Security Groups"         = length(data.aws_security_groups.all.ids)
    "💾  EBS Volumes"             = length(data.aws_ebs_volumes.all.ids)
    "📌  Elastic IPs"             = length(data.aws_eips.all.public_ips)
  }
  description = "สรุปภาพรวมของทรัพยากร AWS ทั้งหมด"
}

# ============================================================================
# 🖥️  รายละเอียด EC2 Instances
# ============================================================================

output "ec2_running" {
  value       = local.running_instances
  description = "รายละเอียดเครื่อง EC2 ที่กำลังทำงานอยู่ (Instance ID → IP Addresses)"
}

output "ec2_stopped_ids" {
  value       = data.aws_instances.stopped.ids
  description = "รายชื่อ Instance IDs ที่หยุดอยู่ (Stopped)"
}

# ============================================================================
# 🌐 รายละเอียดโครงสร้างเครือข่าย
# ============================================================================

output "vpc_details" {
  value       = local.vpc_summary
  description = "รายละเอียด VPCs ทั้งหมด (CIDR, State, Default)"
}

output "subnet_details" {
  value       = local.subnet_by_vpc
  description = "รายละเอียด Subnets ทั้งหมด (Availability Zone, CIDR, Available IPs)"
}

# ============================================================================
# 🔒 รายละเอียดความปลอดภัย
# ============================================================================

output "security_group_summary" {
  value       = local.security_group_rules
  description = "สรุปกฎ Security Groups ทั้งหมด (ชื่อ, จำนวน Inbound/Outbound rules)"
}

# ============================================================================
# 💾 รายละเอียด Storage & Networking
# ============================================================================

output "ebs_volume_ids" {
  value       = data.aws_ebs_volumes.all.ids
  description = "รายชื่อ EBS Volume IDs ทั้งหมดที่มีในระบบ"
}

output "elastic_ips" {
  value       = data.aws_eips.all.public_ips
  description = "รายชื่อ Elastic IPs (EIP) ทั้งหมดที่จองไว้"
}
