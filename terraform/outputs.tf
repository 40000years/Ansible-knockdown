output "total_running_instances" {
  value       = length(data.aws_instances.existing.ids)
  description = "จำนวนเครื่อง EC2 ที่กำลังทำงานอยู่ทั้งหมดใน Region"
}

output "instance_ids" {
  value       = data.aws_instances.existing.ids
  description = "รายชื่อ Instance IDs ของเครื่อง EC2 ทั้งหมดที่กำลังทำงานอยู่"
}

output "private_ips" {
  value       = data.aws_instances.existing.private_ips
  description = "รายชื่อ Private IP Addresses ของเครื่อง EC2 ทั้งหมดที่กำลังทำงานอยู่"
}

output "public_ips" {
  value       = data.aws_instances.existing.public_ips
  description = "รายชื่อ Public IP Addresses ของเครื่อง EC2 ทั้งหมดที่กำลังทำงานอยู่"
}
