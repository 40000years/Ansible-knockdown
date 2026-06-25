output "started_instances" {
  value = {
    for id, inst in aws_ec2_instance_state.target : id => {
      instance_id = inst.instance_id
      state       = inst.state
    }
  }
  description = "EC2 Instances ที่ถูก Start"
}

output "nat_gateway_created" {
  value       = local.create_nat
  description = "มีการสร้าง NAT Gateway ใหม่หรือไม่"
}

output "nat_config" {
  value = local.create_nat ? {
    subnet_id         = var.nat_subnet_id
    eip_allocation_id = var.eip_allocation_id
    route_table_id    = var.route_table_id
  } : null
  description = "ค่าตั้งต้นที่ใช้สร้าง NAT Gateway ใหม่"
}

output "summary" {
  value = <<-EOT
    ===================================
    EC2 Start Workflow Complete
    -----------------------------------
    Instances Started : ${length(var.instance_ids)}
    NAT GW Created    : ${local.create_nat ? "YES" : "NO"}
    Route Table       : ${var.route_table_id != "" ? var.route_table_id : "N/A"}
    Region            : ${var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region}
    -----------------------------------
    ⚠ ดู NAT GW ID ใหม่จาก Log ด้านบน
       (ค้นหา "new_nat_gateway_id=")
    ===================================
  EOT
  description = "สรุปผลการ Start EC2 + สร้าง NAT GW"
}
