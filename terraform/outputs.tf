output"total_running_instances" {
  value       = length(data.aws_instances.existing.ids)
  description = "จำนวนเครื่อง EC2 ที่กำลังทำงานอยู่ทั้งหมดใน Region"
}

output "ec2_instances_summary" {
  value = {
    for id, inst in data.aws_instance.detail : id => {
      instance_name = lookup(inst.tags, "Name", "Unnamed")
      private_ip    = inst.private_ip
      public_ip     = inst.public_ip
      instance_type = inst.instance_type
      state         = inst.instance_state
      environment   = lookup(inst.tags, "Environment", "N/A")
    }
  }
  description = "สรุปข้อมูล EC2 Instances ทั้งหมดที่ดึงข้อมูลมาได้"
}
