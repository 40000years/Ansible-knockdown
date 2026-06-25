output "stopped_instances" {
  value = {
    for id, inst in aws_ec2_instance_state.target : id => {
      instance_id = inst.instance_id
      state       = inst.state
    }
  }
  description = "EC2 Instances ที่ถูก Stop"
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
    Instances Stopped : ${length(local.target_ids)}
    NAT GWs Deleted   : ${length(local.nat_ids_to_delete)}
    Region            : ${local.region}
    ===================================
  EOT
  description = "สรุปผลการ Stop EC2"
}
