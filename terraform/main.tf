# ============================================================================
# 1. EC2 Instances (สิทธิ์เดิมที่มีอยู่ - ใช้งานได้แน่นอน)
# ============================================================================

data "aws_instances" "running" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instances" "stopped" {
  filter {
    name   = "instance-state-name"
    values = ["stopped"]
  }
}

# ============================================================================
# 2. VPC & Networking (ต้องการสิทธิ์จาก iam.tf ก่อน)
# ============================================================================

data "aws_vpcs" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

data "aws_vpc" "detail" {
  for_each   = toset(data.aws_vpcs.all.ids)
  id         = each.value
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

data "aws_subnets" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

data "aws_subnet" "detail" {
  for_each   = toset(data.aws_subnets.all.ids)
  id         = each.value
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

# ============================================================================
# 3. Route Tables
# ============================================================================

data "aws_route_tables" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

data "aws_route_table" "detail" {
  for_each       = toset(data.aws_route_tables.all.ids)
  route_table_id = each.value
  depends_on     = [aws_iam_user_policy_attachment.ansible_readonly]
}

# ============================================================================
# 4. Security Groups
# ============================================================================

data "aws_security_groups" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

data "aws_security_group" "detail" {
  for_each   = toset(data.aws_security_groups.all.ids)
  id         = each.value
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

# ============================================================================
# 5. Storage (EBS Volumes)
# ============================================================================

data "aws_ebs_volumes" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

# ============================================================================
# 6. Elastic IPs
# ============================================================================

data "aws_eips" "all" {
  depends_on = [aws_iam_user_policy_attachment.ansible_readonly]
}

# ============================================================================
# 7. (Reserved for Future Features)
# ============================================================================

# ============================================================================
# 8. Locals: จัดรูปแบบข้อมูลสำหรับ Output
# ============================================================================

locals {
  # EC2 Running instances map
  running_instances = {
    for i, id in data.aws_instances.running.ids : id => {
      private_ip = try(data.aws_instances.running.private_ips[i], "N/A")
      public_ip  = try(data.aws_instances.running.public_ips[i], "No Public IP")
    }
  }

  # VPC Summary
  vpc_summary = {
    for id, vpc in data.aws_vpc.detail : id => {
      cidr_block = vpc.cidr_block
      is_default = vpc.default
      state      = vpc.state
    }
  }

  # Subnet Summary แบ่งตาม AZ
  subnet_summary = {
    for id, subnet in data.aws_subnet.detail : id => {
      vpc_id            = subnet.vpc_id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      available_ips     = subnet.available_ip_address_count
      is_public         = subnet.map_public_ip_on_launch
    }
  }

  # Route Table Summary
  route_table_summary = {
    for id, rt in data.aws_route_table.detail : id => {
      vpc_id      = rt.vpc_id
      routes      = length(rt.routes)
      associations = length(rt.associations)
    }
  }

  # Security Group Summary
  security_group_summary = {
    for id, sg in data.aws_security_group.detail : sg.name => {
      sg_id       = id
      vpc_id      = sg.vpc_id
      description = sg.description
      inbound_rules  = length(sg.ingress)
      outbound_rules = length(sg.egress)
    }
  }
}
