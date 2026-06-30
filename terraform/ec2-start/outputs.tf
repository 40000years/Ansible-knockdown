output "started_instances" {
  value       = var.instance_ids
  description = "EC2 Instances ที่ถูก Start (ถ้าระบุ)"
}

output "summary" {
  value = <<-EOT
    ===================================
    EC2 Start Workflow Complete
    -----------------------------------
    Instances Target  : ${length(var.instance_ids) == 0 ? "Auto-discovered" : length(var.instance_ids)}
    NAT GW Created    : YES (Auto-Configured)
    Region            : ${local.region}
    -----------------------------------
    ⚠ ดูรายละเอียด NAT GW ID, Subnet, Route Table
       ที่ถูก Auto-Discover ได้จาก Log ของ Semaphore ด้านบน
    ===================================
  EOT
  description = "สรุปผลการ Start EC2 + สร้าง NAT GW"
}
