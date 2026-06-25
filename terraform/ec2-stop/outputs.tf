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
  value       = var.nat_gateway_ids
  description = "NAT Gateways ที่ถูกลบก่อน Stop EC2"
}

output "summary" {
  value = <<-EOT
    ===================================
    EC2 Stop Workflow Complete
    -----------------------------------
    Instances Stopped : ${length(var.instance_ids)}
    NAT GWs Deleted   : ${length(var.nat_gateway_ids)}
    Region            : ${var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region}
    ===================================
  EOT
  description = "สรุปผลการ Stop EC2"
}
