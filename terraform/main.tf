# ============================================================================
# 1. ดึง EC2 Instances แบ่งตาม State ต่าง ๆ
# ============================================================================

# ทุก Instance ที่กำลังทำงาน (Running)
data "aws_instances" "running" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# ทุก Instance ที่หยุดอยู่ (Stopped)
data "aws_instances" "stopped" {
  filter {
    name   = "instance-state-name"
    values = ["stopped"]
  }
}

# ============================================================================
# 2. ดึงข้อมูลโครงสร้างเครือข่าย (Network Infrastructure)
# ============================================================================

# ดึง VPC ทั้งหมดที่มีอยู่ในบัญชี AWS นี้
data "aws_vpcs" "all" {}

# ดึงรายละเอียดของแต่ละ VPC ที่ค้นพบ
data "aws_vpc" "detail" {
  for_each = toset(data.aws_vpcs.all.ids)
  id       = each.value
}

# ดึงรายชื่อ Subnets ทั้งหมดในทุก VPC
data "aws_subnets" "all" {}

# ดึงรายละเอียดของแต่ละ Subnet ที่ค้นพบ
data "aws_subnet" "detail" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# ============================================================================
# 3. ดึงข้อมูลความปลอดภัย (Security)
# ============================================================================

# ดึง Security Groups ทั้งหมด
data "aws_security_groups" "all" {}

# ดึงรายละเอียดของแต่ละ Security Group
data "aws_security_group" "detail" {
  for_each = toset(data.aws_security_groups.all.ids)
  id       = each.value
}

# ============================================================================
# 4. ดึงข้อมูล EBS Volumes ทั้งหมด (Storage)
# ============================================================================
data "aws_ebs_volumes" "all" {
  filter {
    name   = "status"
    values = ["in-use", "available"]
  }
}

# ============================================================================
# 5. ดึงข้อมูล Elastic IPs (EIP)
# ============================================================================
data "aws_eips" "all" {}

# ============================================================================
# 6. สร้าง Local Data สำหรับสรุปข้อมูลทั้งหมด
# ============================================================================
locals {
  # จับคู่ IDs กับ IPs ของ running instances
  running_instances = {
    for i, id in data.aws_instances.running.ids : id => {
      private_ip = length(data.aws_instances.running.private_ips) > i ? data.aws_instances.running.private_ips[i] : "N/A"
      public_ip  = length(data.aws_instances.running.public_ips) > i ? data.aws_instances.running.public_ips[i] : "No Public IP"
    }
  }

  # สรุปข้อมูล VPC
  vpc_summary = {
    for id, vpc in data.aws_vpc.detail : id => {
      cidr_block = vpc.cidr_block
      is_default = vpc.default
      state      = vpc.state
    }
  }

  # สรุปข้อมูล Subnet แบ่งตาม VPC
  subnet_by_vpc = {
    for id, subnet in data.aws_subnet.detail : id => {
      vpc_id            = subnet.vpc_id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      available_ips     = subnet.available_ip_address_count
    }
  }

  # สรุปกฎ Security Group
  security_group_rules = {
    for id, sg in data.aws_security_group.detail : sg.name => {
      sg_id       = id
      description = sg.description
      vpc_id      = sg.vpc_id
      ingress     = length(sg.ingress)
      egress      = length(sg.egress)
    }
  }
}
