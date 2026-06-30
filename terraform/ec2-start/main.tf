# ============================================================================
# EC2 START WORKFLOW  (Fully Auto-Config)
# ============================================================================
# ลำดับการทำงาน:
#   1. Auto-discover EC2 ที่ stopped + Public Subnet + EIP + Route Table
#   2. Start EC2 Instances
#   3. รอ EC2 running แล้วสร้าง NAT Gateway ใหม่
#   4. ลบ blackhole route เก่า แล้วชี้ 0.0.0.0/0 → NAT GW ใหม่
#
# ไม่ต้องกรอกค่าอะไรเลย! ระบบหาให้อัตโนมัติทั้งหมด
# ============================================================================

# ============================================================================
# DATA SOURCES — Auto-discover ทุกอย่าง
# ============================================================================

# ค้นหา EC2 ทุกตัวที่หยุดอยู่ (เผื่อกรณี Auto-discover)
data "aws_instances" "stopped" {
  filter {
    name   = "instance-state-name"
    values = ["stopped", "stopping"]
  }
}

# EIP ทั้งหมด (หา allocation ID อัตโนมัติ)
data "aws_eips" "all" {}

# VPCs ทั้งหมด
data "aws_vpcs" "all" {}

locals {
  region = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region

  # EC2 target: ถ้าไม่ระบุ → ใช้ทุกตัวที่ stopped
  stopped_ids = toset(data.aws_instances.stopped.ids)
  target_ids = length(var.instance_ids) == 0 ? local.stopped_ids : toset(var.instance_ids)

  # EIP: ถ้าระบุมาใช้เลย, ถ้าไม่ระบุ → ใช้ตัวแรกที่พบ
  eip_alloc_id = var.eip_allocation_id != "" ? var.eip_allocation_id : (
    length(data.aws_eips.all.allocation_ids) > 0 ? data.aws_eips.all.allocation_ids[0] : ""
  )

  target_ids_str = join(" ", local.target_ids)
}

# ============================================================================
# STEP 1-4: Start EC2, Create NAT GW, Update Route Table (via Bash)
# ============================================================================

resource "null_resource" "create_nat_and_route" {
  # บังคับรันใหม่ทุกครั้ง!
  triggers = {
    run_at  = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_DEFAULT_REGION  = local.region
      TARGET_INSTANCE_IDS = local.target_ids_str
      EIP_ALLOC_ID        = local.eip_alloc_id
      OVERRIDE_SUBNET_ID  = var.nat_subnet_id
      OVERRIDE_RTB_ID     = var.route_table_id
    }
    command = <<-EOT
      set -e

      echo "============================================"
      echo " STEP 1: Starting EC2 Instances..."
      echo "============================================"
      if [ -z "$TARGET_INSTANCE_IDS" ]; then
        echo "  ERROR: No target instances found! 'Targets' is empty."
        echo "  Please manually specify instance_ids variable in Semaphore."
        exit 1
      fi

      echo "  Targets: $TARGET_INSTANCE_IDS"
      
      # สั่ง Start EC2 ผ่าน CLI โดยตรง (แก้ปัญหา Terraform State จำค่าผิด)
      aws ec2 start-instances --instance-ids $TARGET_INSTANCE_IDS >/dev/null
      
      echo "  Waiting for EC2 to be running..."
      aws ec2 wait instance-running --instance-ids $TARGET_INSTANCE_IDS
      echo "  EC2 instances are running ✓"

      # ---- Auto-discover Public Subnet สำหรับสร้าง NAT GW ----
      if [ -n "$OVERRIDE_SUBNET_ID" ]; then
        NAT_SUBNET_ID="$OVERRIDE_SUBNET_ID"
        echo "  Using override subnet: $NAT_SUBNET_ID"
      else
        echo "  Auto-discovering public subnet..."
        # หา subnet ที่มี map_public_ip_on_launch = true (Public Subnet)
        NAT_SUBNET_ID=$(aws ec2 describe-subnets \
          --filters "Name=map-public-ip-on-launch,Values=true" \
          --query 'Subnets[0].SubnetId' \
          --output text 2>/dev/null || echo "")

        if [ -z "$NAT_SUBNET_ID" ] || [ "$NAT_SUBNET_ID" = "None" ]; then
          echo "  ERROR: Cannot find a public subnet for NAT GW!"
          echo "  Please set nat_subnet_id variable manually."
          exit 1
        fi
        echo "  Found public subnet: $NAT_SUBNET_ID"
      fi

      # ---- Auto-discover Route Table ที่มี blackhole route ----
      if [ -n "$OVERRIDE_RTB_ID" ]; then
        ROUTE_TABLE_ID="$OVERRIDE_RTB_ID"
        echo "  Using override route table: $ROUTE_TABLE_ID"
      else
        echo "  Auto-discovering route table with blackhole route..."
        ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
          --filters "Name=route.state,Values=blackhole" \
          --query 'RouteTables[0].RouteTableId' \
          --output text 2>/dev/null || echo "")

        if [ -z "$ROUTE_TABLE_ID" ] || [ "$ROUTE_TABLE_ID" = "None" ]; then
          echo "  No blackhole route found. Looking for main route table..."
          ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
            --filters "Name=association.main,Values=true" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null || echo "")
        fi

        if [ -z "$ROUTE_TABLE_ID" ] || [ "$ROUTE_TABLE_ID" = "None" ]; then
          echo "  ERROR: Cannot find route table to update!"
          echo "  Please set route_table_id variable manually."
          exit 1
        fi
        echo "  Found route table: $ROUTE_TABLE_ID"
      fi

      # ---- EIP ----
      if [ -z "$EIP_ALLOC_ID" ]; then
        echo "  ERROR: No Elastic IP found! Please allocate an EIP first."
        exit 1
      fi
      echo "  Using EIP allocation: $EIP_ALLOC_ID"

      echo "============================================"
      echo " STEP 2: Creating NAT Gateway"
      echo "============================================"
      NAT_ID=$(aws ec2 create-nat-gateway \
        --subnet-id "$NAT_SUBNET_ID" \
        --allocation-id "$EIP_ALLOC_ID" \
        --query 'NatGateway.NatGatewayId' \
        --output text)

      echo "  NAT GW created: $NAT_ID"
      echo "  Waiting for NAT GW to become available (1-2 min)..."
      aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"
      echo "  NAT GW $NAT_ID: AVAILABLE ✓"

      echo "============================================"
      echo " STEP 3: Updating Route Table: $ROUTE_TABLE_ID"
      echo "============================================"

      # ลบ route 0.0.0.0/0 เก่า (blackhole)
      aws ec2 delete-route \
        --route-table-id "$ROUTE_TABLE_ID" \
        --destination-cidr-block "0.0.0.0/0" 2>/dev/null \
        && echo "  Old 0.0.0.0/0 route removed." \
        || echo "  No existing 0.0.0.0/0 route (OK)."

      # เพิ่ม route ใหม่
      aws ec2 create-route \
        --route-table-id "$ROUTE_TABLE_ID" \
        --destination-cidr-block "0.0.0.0/0" \
        --nat-gateway-id "$NAT_ID"

      echo "  Route 0.0.0.0/0 → $NAT_ID ✓"
      echo "============================================"
      echo " START WORKFLOW COMPLETE"
      echo "  New NAT GW ID : $NAT_ID"
      echo "  Public Subnet : $NAT_SUBNET_ID"
      echo "  Route Table   : $ROUTE_TABLE_ID"
      echo "============================================"
    EOT
  }
}
