output "stopped_instances" {
  value       = var.instance_ids
  description = "EC2 Instances ที่ถูก Stop (ถ้าระบุ)"
}

output "deleted_nat_gateways" {
  value       = local.nat_ids_to_delete
  description = "NAT Gateways ที่ถูกลบก่อน Stop EC2"
}

output "summary" {
  value = <<-EOT
    ===================================
    EC2 Stop Workflow Complete
    -----------------------------------
    Instances Target  : ${length(var.instance_ids) == 0 ? "Auto-discovered" : length(var.instance_ids)}
    NAT GWs Deleted   : ${length(local.nat_ids_to_delete)}
    Region            : ${local.region}
    ===================================
  EOT
  description = "สรุปผลการ Stop EC2"
}
