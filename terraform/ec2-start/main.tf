# ============================================================================
# EC2 START WORKFLOW
# ============================================================================
# ลำดับการทำงาน:
#   1. Start EC2 Instances
#   2. รอให้ EC2 อยู่ในสถานะ running
#   3. สร้าง NAT Gateway ใหม่ใน Public Subnet (ถ้า create_nat_gateway = true)
#   4. อัปเดต Route Table ให้ 0.0.0.0/0 ชี้ไปที่ NAT GW ใหม่
# ============================================================================

locals {
  region     = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region
  create_nat = var.create_nat_gateway && var.nat_subnet_id != "" && var.eip_allocation_id != ""
}

# ============================================================================
# STEP 1: Start EC2 Instances
# ============================================================================

resource "aws_ec2_instance_state" "target" {
  for_each    = toset(var.instance_ids)
  instance_id = each.value
  state       = "running"
}

# ============================================================================
# STEP 2 + 3 + 4: Create NAT GW และ Update Route Table
# (รันหลัง EC2 เริ่ม Start แล้ว — ทำงานแบบ parallel ได้เพราะ EC2 ไม่ขึ้นกับ NAT GW)
# ============================================================================

resource "null_resource" "create_nat_and_route" {
  count = local.create_nat ? 1 : 0

  # ทำใหม่ทุกครั้งที่รัน
  triggers = {
    instance_ids      = join(",", sort(var.instance_ids))
    nat_subnet_id     = var.nat_subnet_id
    eip_allocation_id = var.eip_allocation_id
    route_table_id    = var.route_table_id
    run_at            = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION    = local.region
    }
    command = <<-EOT
      set -e

      echo "============================================"
      echo " STEP 2: Waiting for EC2 to be running..."
      echo "============================================"
      INSTANCE_IDS="${join(" ", var.instance_ids)}"
      aws ec2 wait instance-running --instance-ids $INSTANCE_IDS
      echo " EC2 instances are running ✓"

      echo "============================================"
      echo " STEP 3: Creating NAT Gateway"
      echo "============================================"
      echo "  Subnet  : ${var.nat_subnet_id}"
      echo "  EIP Alloc: ${var.eip_allocation_id}"

      NAT_ID=$(aws ec2 create-nat-gateway \
        --subnet-id "${var.nat_subnet_id}" \
        --allocation-id "${var.eip_allocation_id}" \
        --query 'NatGateway.NatGatewayId' \
        --output text)

      echo "  NAT GW created: $NAT_ID"
      echo "  Waiting for NAT GW to become available..."
      aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"
      echo "  NAT GW $NAT_ID: AVAILABLE ✓"

      echo "============================================"
      echo " STEP 4: Updating Route Table"
      echo "============================================"
      echo "  Route Table: ${var.route_table_id}"

      # ลบ route 0.0.0.0/0 เก่าก่อน (ถ้ามี blackhole route หลังจาก stop)
      aws ec2 delete-route \
        --route-table-id "${var.route_table_id}" \
        --destination-cidr-block "0.0.0.0/0" 2>/dev/null \
        && echo "  Old 0.0.0.0/0 route removed." \
        || echo "  No existing 0.0.0.0/0 route found (OK)."

      # เพิ่ม route ใหม่ชี้ไปที่ NAT GW
      aws ec2 create-route \
        --route-table-id "${var.route_table_id}" \
        --destination-cidr-block "0.0.0.0/0" \
        --nat-gateway-id "$NAT_ID"

      echo "  Route 0.0.0.0/0 → $NAT_ID added ✓"

      echo "============================================"
      echo " START WORKFLOW COMPLETE"
      echo "  New NAT GW ID: $NAT_ID"
      echo "  IMPORTANT: ใช้ NAT GW ID นี้ตอนสั่ง Stop ครั้งถัดไป"
      echo "============================================"

      # บันทึก NAT GW ID ไว้ใน output (ดูได้จาก Semaphore log)
      echo "new_nat_gateway_id=$NAT_ID"
    EOT
  }

  depends_on = [aws_ec2_instance_state.target]
}
