# ============================================================================
# 1. EC2 Instances
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

# EC2 Instance Detail (Tags, Type, AZ) — สำหรับ Grouping Output
data "aws_instance" "detail" {
  for_each    = toset(data.aws_instances.running.ids)
  instance_id = each.value
}

# ============================================================================
# 2. VPC & Networking
# ============================================================================

data "aws_vpcs" "all" {}

data "aws_vpc" "detail" {
  for_each = toset(data.aws_vpcs.all.ids)
  id       = each.value
}

data "aws_subnets" "all" {}

data "aws_subnet" "detail" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# ============================================================================
# 3. Route Tables
# ============================================================================

data "aws_route_tables" "all" {}

data "aws_route_table" "detail" {
  for_each       = toset(data.aws_route_tables.all.ids)
  route_table_id = each.value
}

# ============================================================================
# 3a. Internet Gateways
# ============================================================================

data "aws_internet_gateway" "detail" {
  for_each = toset(data.aws_vpcs.all.ids)
  filter {
    name   = "attachment.vpc-id"
    values = [each.value]
  }
}

# ============================================================================
# 3b. NAT Gateways
# ============================================================================

data "aws_nat_gateways" "all" {}

data "aws_nat_gateway" "detail" {
  for_each = toset(data.aws_nat_gateways.all.ids)
  id       = each.value
}

# ============================================================================
# 4. Security Groups
# ============================================================================

data "aws_security_groups" "all" {}

data "aws_security_group" "detail" {
  for_each = toset(data.aws_security_groups.all.ids)
  id       = each.value
}

# ============================================================================
# 5. Storage (EBS Volumes)
# ============================================================================

data "aws_ebs_volumes" "all" {}

# ============================================================================
# 6. Elastic IPs
# ============================================================================

data "aws_eips" "all" {}

# ============================================================================
# 7. Force Output in Semaphore UI (Dummy Resource)
# ============================================================================
# Semaphore UI hides outputs if there are 0 changes. This dummy resource 
# changes every time, forcing Semaphore to print the outputs.
resource "terraform_data" "force_semaphore_output" {
  triggers_replace = timestamp()
}

# ============================================================================
# 8. Locals: Summary + Advanced Grouping
# ============================================================================

locals {
  # --------------------------------------------------------------------------
  # EC2 Running instances — basic map (id → IPs)
  # --------------------------------------------------------------------------
  running_instances = {
    for i, id in data.aws_instances.running.ids : id => {
      private_ip = try(data.aws_instances.running.private_ips[i], "N/A")
      public_ip  = try(data.aws_instances.running.public_ips[i], "No Public IP")
    }
  }

  # --------------------------------------------------------------------------
  # EC2 Running instances — detail map (id → full info + Tags)
  # Used by: ansible_inventory_json, ec2_grouped_by_environment
  # --------------------------------------------------------------------------
  running_instances_detail = {
    for id, inst in data.aws_instance.detail : id => {
      private_ip        = inst.private_ip
      public_ip         = coalesce(inst.public_ip, "No Public IP")
      instance_type     = inst.instance_type
      availability_zone = inst.availability_zone
      key_name          = coalesce(inst.key_name, "none")
      name              = try(inst.tags["Name"], id)
      environment       = try(inst.tags["Environment"], "untagged")
      role              = try(inst.tags["Role"], "untagged")
    }
  }

  # --------------------------------------------------------------------------
  # EC2 Grouped by "Environment" Tag
  # Output: { "production" = { instance_ids=[...], private_ips=[...] }, ... }
  # --------------------------------------------------------------------------
  ec2_grouped_by_environment = {
    for env in distinct([for inst in local.running_instances_detail : inst.environment]) :
    env => {
      instance_ids = [for id, inst in local.running_instances_detail : id if inst.environment == env]
      private_ips  = [for id, inst in local.running_instances_detail : inst.private_ip if inst.environment == env]
      public_ips   = [for id, inst in local.running_instances_detail : inst.public_ip if inst.environment == env && inst.public_ip != "No Public IP"]
    }
  }

  # --------------------------------------------------------------------------
  # Ansible Dynamic Inventory JSON (RFC-compliant format)
  # OpenTofu/Terraform outputs this — Ansible reads it via script inventory
  # --------------------------------------------------------------------------
  ansible_inventory = {
    all = {
      hosts    = [for _, inst in local.running_instances_detail : inst.private_ip]
      children = keys(local.ec2_grouped_by_environment)
    }
    _meta = {
      hostvars = {
        for _, inst in local.running_instances_detail : inst.private_ip => {
          ansible_host          = inst.private_ip
          ansible_user          = "ubuntu"
          instance_id           = [for id, i in local.running_instances_detail : id if i.private_ip == inst.private_ip][0]
          instance_type         = inst.instance_type
          availability_zone     = inst.availability_zone
          environment           = inst.environment
          role                  = inst.role
          name                  = inst.name
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # VPC Summary
  # --------------------------------------------------------------------------
  vpc_summary = {
    for id, vpc in data.aws_vpc.detail : id => {
      cidr_block = vpc.cidr_block
      is_default = vpc.default
      state      = vpc.state
    }
  }

  # --------------------------------------------------------------------------
  # Subnet Summary แบ่งตาม AZ
  # --------------------------------------------------------------------------
  subnet_summary = {
    for id, subnet in data.aws_subnet.detail : id => {
      vpc_id            = subnet.vpc_id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      available_ips     = subnet.available_ip_address_count
      is_public         = subnet.map_public_ip_on_launch
    }
  }

  # --------------------------------------------------------------------------
  # Network Topology: VPC → Subnets (nested grouping)
  # --------------------------------------------------------------------------
  network_topology = {
    for vpc_id, vpc in data.aws_vpc.detail : vpc_id => {
      cidr_block = vpc.cidr_block
      is_default = vpc.default
      subnets = {
        for sn_id, sn in data.aws_subnet.detail : sn_id => {
          cidr_block        = sn.cidr_block
          availability_zone = sn.availability_zone
          is_public         = sn.map_public_ip_on_launch
          available_ips     = sn.available_ip_address_count
        }
        if sn.vpc_id == vpc_id
      }
    }
  }

  # --------------------------------------------------------------------------
  # Route Table Detail — แสดง Routes จริง (destination → target)
  # --------------------------------------------------------------------------
  route_table_summary = {
    for id, rt in data.aws_route_table.detail : id => {
      vpc_id       = rt.vpc_id
      is_main      = anytrue([for a in rt.associations : a.main])
      associations = length(rt.associations)
      routes = [
        for r in rt.routes : {
          destination = coalesce(
            r.destination_cidr_block,
            try(r.destination_ipv6_cidr_block, ""),
            try(r.destination_prefix_list_id, "unknown")
          )
          target = coalesce(
            try(r.gateway_id != "" ? r.gateway_id : null, null),
            try(r.nat_gateway_id != "" ? r.nat_gateway_id : null, null),
            try(r.transit_gateway_id != "" ? r.transit_gateway_id : null, null),
            try(r.vpc_peering_connection_id != "" ? r.vpc_peering_connection_id : null, null),
            try(r.network_interface_id != "" ? r.network_interface_id : null, null),
            try(r.instance_id != "" ? r.instance_id : null, null),
            "local"
          )
          state = r.state
        }
      ]
    }
  }

  # --------------------------------------------------------------------------
  # Internet Gateway Summary
  # --------------------------------------------------------------------------
  internet_gateway_summary = {
    for vpc_id, igw in data.aws_internet_gateway.detail : vpc_id => {
      igw_id     = igw.id
      state      = try(igw.attachments[0].state, "detached")
      owner_id   = igw.owner_id
    }
  }

  # --------------------------------------------------------------------------
  # NAT Gateway Summary
  # --------------------------------------------------------------------------
  nat_gateway_summary = {
    for id, nat in data.aws_nat_gateway.detail : id => {
      vpc_id            = nat.vpc_id
      subnet_id         = nat.subnet_id
      state             = nat.state
      connectivity_type = nat.connectivity_type
      public_ip         = try(nat.public_ip, "N/A")
      private_ip        = try(nat.private_ip, "N/A")
    }
  }

  # --------------------------------------------------------------------------
  # Security Group Summary
  # --------------------------------------------------------------------------
  security_group_summary = {
    for id, sg in data.aws_security_group.detail : id => {
      name        = sg.name
      vpc_id      = sg.vpc_id
      description = sg.description
    }
  }
}
