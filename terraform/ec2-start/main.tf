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

# ไม่ใช้ data.aws_instances ของ Terraform แล้ว 
# เพราะมีบั๊กคืนค่าว่างเปล่า จะใช้ AWS CLI ดึงแทน

# EIP ทั้งหมด (หา allocation ID อัตโนมัติ)
data "aws_eips" "all" {}

# VPCs ทั้งหมด
data "aws_vpcs" "all" {}

locals {
  region = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region

  # ถ้า user ระบุผ่าน UI ก็ใช้ตัวนั้น ถ้าไม่ระบุจะปล่อยว่างให้ Bash ไปหาเอง
  target_ids_str = join(" ", var.instance_ids)

  # EIP: ถ้าระบุมาใช้เลย, ถ้าไม่ระบุ → ใช้ตัวแรกที่พบ
  eip_alloc_id = var.eip_allocation_id != "" ? var.eip_allocation_id : (
    length(data.aws_eips.all.allocation_ids) > 0 ? data.aws_eips.all.allocation_ids[0] : ""
  )
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
      set -x

      echo "============================================"
      echo " STEP 1: Starting EC2 Instances..."
      echo "============================================"
      if [ -z "$TARGET_INSTANCE_IDS" ]; then
        echo "  No target instances specified. Auto-discovering stopped instances via AWS CLI..."
        TARGET_INSTANCE_IDS=$(aws ec2 describe-instances \
          --filters "Name=instance-state-name,Values=stopped,stopping" \
          --query 'Reservations[*].Instances[*].InstanceId' \
          --output text | tr -s '\t\n' ' ')
      fi

      if [ -z "$TARGET_INSTANCE_IDS" ] || [ "$TARGET_INSTANCE_IDS" = " " ]; then
        echo "  WARNING: No stopped instances found in AWS! (They might already be running)."
        echo "  Skipping instance start step and proceeding to NAT GW creation..."
        
        # แต่เรายังต้องใช้ Instance ID เพื่อไปหา VPC และ Subnet ใน Step ถัดไป!
        # ดังนั้นถ้าไม่เจอเครื่องดับ ให้หาเครื่องที่เปิดอยู่มาใช้แทน
        TARGET_INSTANCE_IDS=$(aws ec2 describe-instances \
          --filters "Name=instance-state-name,Values=running" \
          --query 'Reservations[*].Instances[*].InstanceId' \
          --output text | tr -s '\t\n' ' ')
          
        if [ -z "$TARGET_INSTANCE_IDS" ] || [ "$TARGET_INSTANCE_IDS" = " " ]; then
          echo "  ERROR: No stopped OR running instances found! Cannot determine VPC."
          exit 1
        fi
      else
        echo "  Targets: $TARGET_INSTANCE_IDS"
        # สั่ง Start EC2 ผ่าน CLI โดยตรง (แก้ปัญหา Terraform State จำค่าผิด)
        aws ec2 start-instances --instance-ids $TARGET_INSTANCE_IDS >/dev/null
        
        echo "  Waiting for EC2 to be running..."
        aws ec2 wait instance-running --instance-ids $TARGET_INSTANCE_IDS
        echo "  EC2 instances are running ✓"
      fi

      # ======================================================================
      # BULLETPROOF AUTO-DISCOVERY: NAT Subnet & Private Route Table
      # ======================================================================
      
      # 1. หา VPC ของเครื่อง EC2
      VPC_ID=$(aws ec2 describe-instances --instance-ids $TARGET_INSTANCE_IDS --query 'Reservations[0].Instances[0].VpcId' --output text)
      echo "  EC2 is in VPC: $VPC_ID"

      # 2. หา Public Subnet (สำหรับวาง NAT GW) โดยการสแกนทุก Subnet ใน VPC หาอันที่ออก IGW ได้
      if [ -n "$OVERRIDE_SUBNET_ID" ]; then
        NAT_SUBNET_ID="$OVERRIDE_SUBNET_ID"
        echo "  Using override subnet: $NAT_SUBNET_ID"
      else
        echo "  Auto-discovering true Public Subnet..."
        NAT_SUBNET_ID=""
        
        ALL_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
        for sub in $ALL_SUBNETS; do
          # หา Route Table ของ Subnet นี้
          RTB=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$sub" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "None")
          if [ "$RTB" = "None" ]; then
            RTB=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --query 'RouteTables[0].RouteTableId' --output text)
          fi
          
          # เช็คว่า Route Table นี้มีเส้นทางออก Internet Gateway (igw-*) หรือไม่
          HAS_IGW=$(aws ec2 describe-route-tables --route-table-ids "$RTB" --query 'RouteTables[0].Routes[*].GatewayId' --output text 2>/dev/null | grep -o 'igw-[a-zA-Z0-9]*' | head -n 1)
          if [ -z "$HAS_IGW" ]; then HAS_IGW="None"; fi
          
          if [ "$HAS_IGW" != "None" ] && [ -n "$HAS_IGW" ]; then
            NAT_SUBNET_ID=$sub
            echo "  Found Public Subnet: $NAT_SUBNET_ID (Route Table: $RTB -> $HAS_IGW)"
            break
          fi
        done

        if [ -z "$NAT_SUBNET_ID" ]; then
          echo "  ERROR: Cannot find any public subnet (with IGW route) in VPC $VPC_ID!"
          exit 1
        fi
      fi

      # 3. หาและอัปเดต Route Table ของ EC2 ทุกเครื่อง (รองรับ multi-instance หลาย subnet)
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
      echo " STEP 3: Update ALL Private Route Tables in VPC → NAT GW"
      echo "============================================"

      if [ -n "$OVERRIDE_RTB_ID" ]; then
        # ถ้า override ให้อัปเดตแค่ตัวนั้น
        echo "  Using override route table: $OVERRIDE_RTB_ID"
        UPDATED_RTBS="$OVERRIDE_RTB_ID"
        aws ec2 delete-route --route-table-id "$OVERRIDE_RTB_ID" --destination-cidr-block "0.0.0.0/0" 2>/dev/null \
          && echo "  Old 0.0.0.0/0 route removed from $OVERRIDE_RTB_ID." \
          || echo "  No existing 0.0.0.0/0 route in $OVERRIDE_RTB_ID (OK)."
        aws ec2 create-route --route-table-id "$OVERRIDE_RTB_ID" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$NAT_ID"
        echo "  Route 0.0.0.0/0 → $NAT_ID updated in $OVERRIDE_RTB_ID ✓"
      else
        # ดึง Route Table ทุกอันใน VPC
        echo "  Scanning ALL route tables in VPC $VPC_ID..."
        ALL_VPC_RTBS=$(aws ec2 describe-route-tables \
          --filters "Name=vpc-id,Values=$VPC_ID" \
          --query 'RouteTables[*].RouteTableId' \
          --output text | tr '\t' '\n' | sort -u)

        echo "  All route tables in VPC: $(echo $ALL_VPC_RTBS | tr '\n' ' ')"

        # หา IGW ของ VPC นี้ (เพื่อแยก public RTB ออก)
        VPC_IGW=$(aws ec2 describe-internet-gateways \
          --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
          --query 'InternetGateways[0].InternetGatewayId' \
          --output text 2>/dev/null || echo "None")
        echo "  VPC Internet Gateway: $VPC_IGW"

        UPDATED_RTBS=""
        for RTB in $ALL_VPC_RTBS; do
          # เช็คว่า Route Table นี้มี IGW route หรือไม่ (= public RTB → ข้าม)
          if [ -n "$VPC_IGW" ] && [ "$VPC_IGW" != "None" ]; then
            HAS_IGW_ROUTE=$(aws ec2 describe-route-tables \
              --route-table-ids "$RTB" \
              --query "RouteTables[0].Routes[?GatewayId=='$VPC_IGW'].GatewayId" \
              --output text 2>/dev/null)
            if [ -n "$HAS_IGW_ROUTE" ]; then
              echo "  Skipping public route table $RTB (has IGW route: $HAS_IGW_ROUTE)"
              continue
            fi
          fi

          echo "  Updating private Route Table $RTB..."
          aws ec2 delete-route --route-table-id "$RTB" --destination-cidr-block "0.0.0.0/0" 2>/dev/null \
            && echo "    Old 0.0.0.0/0 route removed." \
            || echo "    No existing 0.0.0.0/0 route (OK)."
          aws ec2 create-route --route-table-id "$RTB" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "$NAT_ID" \
            && echo "    Route 0.0.0.0/0 → $NAT_ID ✓" \
            || echo "    WARNING: Failed to create route in $RTB"

          UPDATED_RTBS="$UPDATED_RTBS $RTB"
        done
      fi

      echo "============================================"
      echo " START WORKFLOW COMPLETE"
      echo "  New NAT GW ID    : $NAT_ID"
      echo "  Public Subnet    : $NAT_SUBNET_ID"
      echo "  Route Tables     :$UPDATED_RTBS"
      echo "============================================"
    EOT
  }
}
