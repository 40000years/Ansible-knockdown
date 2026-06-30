# ============================================================================
# EC2 STOP WORKFLOW
# ============================================================================
# ลำดับการทำงาน:
#   1. ค้นหา NAT Gateway ที่ active ในทุก VPC ของ region (ไม่ขึ้นกับ EC2 state)
#   2. ลบ NAT Gateway ทั้งหมดที่พบ (รอจนกว่าจะ deleted สมบูรณ์)
#   3. Stop EC2 Instances ที่ running อยู่
#
# หมายเหตุ: เมื่อลบ NAT GW แล้ว AWS จะ mark routes เป็น "blackhole" อัตโนมัติ
# ============================================================================

# ============================================================================
# DATA SOURCES
# ============================================================================

# ไม่ใช้ data.aws_instances ของ Terraform แล้ว 
# เพราะมีบั๊กคืนค่าว่างเปล่า จะใช้ AWS CLI ดึงแทน

# ดึง NAT GW ทั้งหมดที่ active ใน region โดยตรง (ไม่ขึ้นกับ EC2 state!)
data "aws_nat_gateways" "active" {
  filter {
    name   = "state"
    values = ["available", "pending"]
  }
}

locals {
  region = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region

  # ถ้า user ระบุผ่าน UI ก็ใช้ตัวนั้น ถ้าไม่ระบุจะปล่อยว่างให้ Bash ไปหาเอง
  target_ids_str = join(" ", var.instance_ids)

  # NAT GW target: ถ้าระบุมาใช้เลย, ถ้าไม่ระบุ → ใช้ทุกตัวที่ active ใน region
  discovered_nat_ids = toset(data.aws_nat_gateways.active.ids)
  nat_ids_to_delete = length(var.nat_gateway_ids) == 0 ? local.discovered_nat_ids : toset(var.nat_gateway_ids)

  nat_ids_str    = join(" ", local.nat_ids_to_delete)
}

# ============================================================================
# STEP 1+2: ลบ NAT Gateways ทั้งหมดที่ active (ก่อน Stop EC2 เสมอ)
# ============================================================================

resource "null_resource" "delete_nat_gateways" {
  triggers = {
    nat_ids = local.nat_ids_str
    run_at  = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_DEFAULT_REGION = local.region
      NAT_IDS            = local.nat_ids_str
    }
    command = <<-EOT
      set -e
      echo "============================================"
      echo " STEP 1: NAT Gateway Cleanup"
      echo "============================================"
      echo "  NAT GWs to delete: ${local.nat_ids_str != "" ? local.nat_ids_str : "(none found)"}"

      if [ -z "$NAT_IDS" ]; then
        echo "  No active NAT Gateways found in region. Skipping."
      else
        for nat_id in $NAT_IDS; do
          STATUS=$(aws ec2 describe-nat-gateways \
            --nat-gateway-ids "$nat_id" \
            --query 'NatGateways[0].State' \
            --output text 2>/dev/null || echo "not-found")

          if [ "$STATUS" = "deleted" ] || [ "$STATUS" = "not-found" ]; then
            echo "  NAT GW $nat_id already gone. Skipping."
            continue
          fi

          echo "  Deleting NAT GW: $nat_id (state: $STATUS)"
          aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id"

          echo "  Waiting for $nat_id to be fully deleted..."
          aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$nat_id"
          echo "  NAT GW $nat_id: DELETED ✓"
        done
        echo "  All NAT Gateways deleted."
      fi
      echo "============================================"
    EOT
  }
}

# ============================================================================
# STEP 3: Stop EC2 Instances (ต้องรอ Step 1-2 เสร็จก่อนเสมอ)
# ============================================================================

resource "null_resource" "stop_instances" {
  # บังคับรันใหม่ทุกครั้ง!
  triggers = {
    run_at = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_DEFAULT_REGION  = local.region
      TARGET_INSTANCE_IDS = local.target_ids_str
    }
    command = <<-EOT
      set -e
      set -x

      echo "============================================"
      echo " STEP 3: Stopping EC2 Instances"
      echo "============================================"
      
      if [ -z "$TARGET_INSTANCE_IDS" ]; then
        echo "  No target instances specified. Auto-discovering running instances via AWS CLI..."
        TARGET_INSTANCE_IDS=$(aws ec2 describe-instances \
          --filters "Name=instance-state-name,Values=running" \
          --query 'Reservations[*].Instances[*].InstanceId' \
          --output text | tr -s '\t\n' ' ')
      fi

      if [ -z "$TARGET_INSTANCE_IDS" ] || [ "$TARGET_INSTANCE_IDS" = " " ]; then
        echo "  No target instances found running in AWS. Skipping."
        exit 0
      fi

      echo "  Targets: $TARGET_INSTANCE_IDS"
      
      # สั่ง Stop EC2 ผ่าน CLI โดยตรง (แก้ปัญหา Terraform State จำค่าผิด)
      aws ec2 stop-instances --instance-ids $TARGET_INSTANCE_IDS >/dev/null
      
      echo "  Waiting for EC2 to be fully stopped..."
      aws ec2 wait instance-stopped --instance-ids $TARGET_INSTANCE_IDS
      echo "  EC2 instances are STOPPED ✓"
      echo "============================================"
    EOT
  }

  depends_on = [null_resource.delete_nat_gateways]
}

