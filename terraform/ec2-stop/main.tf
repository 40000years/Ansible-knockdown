# ============================================================================
# EC2 STOP WORKFLOW
# ============================================================================
# ลำดับการทำงาน:
#   1. Auto-discover NAT Gateway ที่อยู่ใน Subnet เดียวกับ EC2 target
#   2. ลบ NAT Gateway (รอจนกว่าจะ deleted สมบูรณ์)
#   3. Stop EC2 Instances
#
# หมายเหตุ: เมื่อลบ NAT GW แล้ว AWS จะ mark routes ที่ชี้ไปที่ NAT GW
# เป็น "blackhole" อัตโนมัติ ไม่ต้องลบ route เอง
# ============================================================================

# ============================================================================
# AUTO-DISCOVER EC2: ดึงเฉพาะ EC2 ที่ running อยู่จริง
# ============================================================================

data "aws_instances" "running" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

locals {
  region = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region

  # ถ้า instance_ids ว่าง → ใช้ auto-discover (เฉพาะที่ running จริงใน AWS)
  # ถ้าระบุมา → ใช้ค่าที่ระบุ (และกรองเฉพาะที่อยู่ใน running list ด้วย)
  running_ids = toset(data.aws_instances.running.ids)
  target_ids = length(var.instance_ids) == 0 ? local.running_ids : toset([
    for id in var.instance_ids : id if contains(tolist(local.running_ids), id)
  ])

  # nat_gateway_ids: ถ้าระบุมาให้ใช้เลย, ถ้าไม่ระบุ → script จะ auto-discover
  extra_nat_ids = join(" ", var.nat_gateway_ids)
  target_ids_str = join(" ", local.target_ids)
}

# ============================================================================
# STEP 1+2: Auto-discover NAT GW จาก EC2 Subnet แล้วลบ (ก่อน Stop EC2)
# ============================================================================

resource "null_resource" "delete_nat_gateways" {
  # ทำใหม่ทุกครั้งที่รัน
  triggers = {
    targets = local.target_ids_str
    run_at  = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION    = local.region
      TARGET_INSTANCE_IDS   = local.target_ids_str
      EXTRA_NAT_IDS         = local.extra_nat_ids
    }
    command = <<-EOT
      set -e
      echo "============================================"
      echo " STEP 1: Auto-discover NAT Gateways"
      echo "============================================"
      echo "  Target EC2s: $TARGET_INSTANCE_IDS"

      # รวม NAT GW ที่ auto-discover + ที่ระบุมาเพิ่ม
      ALL_NAT_IDS="$EXTRA_NAT_IDS"

      for instance_id in $TARGET_INSTANCE_IDS; do
        echo "  Looking up Subnet for EC2: $instance_id"

        SUBNET_ID=$(aws ec2 describe-instances \
          --instance-ids "$instance_id" \
          --query 'Reservations[0].Instances[0].SubnetId' \
          --output text 2>/dev/null || echo "")

        VPC_ID=$(aws ec2 describe-instances \
          --instance-ids "$instance_id" \
          --query 'Reservations[0].Instances[0].VpcId' \
          --output text 2>/dev/null || echo "")

        if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
          echo "  Could not find subnet for $instance_id, skipping NAT lookup."
          continue
        fi

        echo "  EC2 $instance_id is in Subnet: $SUBNET_ID (VPC: $VPC_ID)"

        # หา NAT GW ที่อยู่ใน VPC เดียวกัน และ state = available/pending
        FOUND_NATS=$(aws ec2 describe-nat-gateways \
          --filter "Name=vpc-id,Values=$VPC_ID" \
                   "Name=state,Values=available,pending" \
          --query 'NatGateways[*].NatGatewayId' \
          --output text 2>/dev/null || echo "")

        if [ -n "$FOUND_NATS" ]; then
          echo "  Found NAT GWs in VPC $VPC_ID: $FOUND_NATS"
          ALL_NAT_IDS="$ALL_NAT_IDS $FOUND_NATS"
        else
          echo "  No active NAT GWs found in VPC $VPC_ID"
        fi
      done

      # ลบ NAT GW ที่พบทั้งหมด (deduplicate)
      UNIQUE_NATS=$(echo "$ALL_NAT_IDS" | tr ' ' '\n' | sort -u | grep -v '^$' || true)

      if [ -z "$UNIQUE_NATS" ]; then
        echo "  No NAT Gateways to delete. Proceeding to Stop EC2."
      else
        echo "============================================"
        echo " STEP 2: Deleting NAT Gateways"
        echo "============================================"
        for nat_id in $UNIQUE_NATS; do
          STATUS=$(aws ec2 describe-nat-gateways \
            --nat-gateway-ids "$nat_id" \
            --query 'NatGateways[0].State' \
            --output text 2>/dev/null || echo "not-found")

          if [ "$STATUS" = "deleted" ] || [ "$STATUS" = "not-found" ]; then
            echo "  NAT GW $nat_id already deleted. Skipping."
            continue
          fi

          echo "  Deleting NAT GW: $nat_id (state: $STATUS)"
          aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id"

          echo "  Waiting for NAT GW $nat_id to be fully deleted..."
          aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$nat_id"
          echo "  NAT GW $nat_id: DELETED ✓"
        done
        echo " All NAT Gateways deleted successfully."
        echo "============================================"
      fi
    EOT
  }
}

# ============================================================================
# STEP 3: Stop EC2 Instances (ต้องรอ Step 1-2 เสร็จก่อนเสมอ)
# ============================================================================

resource "aws_ec2_instance_state" "target" {
  for_each    = local.target_ids
  instance_id = each.value
  state       = "stopped"

  # บังคับให้ทำหลัง NAT GW ถูกลบเสมอ
  depends_on = [null_resource.delete_nat_gateways]
}

