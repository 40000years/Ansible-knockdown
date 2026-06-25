output "started_instances" {
  value = {
    for id, inst in aws_ec2_instance_state.target : id => {
      instance_id = inst.instance_id
      state       = inst.state
    }
  }
  description = "EC2 Instances ที่ถูก Start"
}

output "summary" {
  value = <<-EOT
    ===================================
    EC2 Start Workflow Complete
    -----------------------------------
    Instances Started : ${length(local.target_ids)}
    NAT GW Created    : YES (Auto-Configured)
    Region            : ${local.region}
    -----------------------------------
    ⚠ ดูรายละเอียด NAT GW ID, Subnet, Route Table
       ที่ถูก Auto-Discover ได้จาก Log ของ Semaphore ด้านบน
    ===================================
  EOT
  description = "สรุปผลการ Start EC2 + สร้าง NAT GW"
}
