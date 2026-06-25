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

# ดึง EC2 ที่ running (สำหรับ stop)
data "aws_instances" "running" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# ดึง NAT GW ทั้งหมดที่ active ใน region โดยตรง (ไม่ขึ้นกับ EC2 state!)
data "aws_nat_gateways" "active" {
  filter {
    name   = "state"
    values = ["available", "pending"]
  }
}

locals {
  region = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region

  # EC2 target: ถ้าไม่ระบุ → ใช้ทุกตัวที่ running
  running_ids = toset(data.aws_instances.running.ids)
  target_ids = length(var.instance_ids) == 0 ? local.running_ids : toset([
    for id in var.instance_ids : id if contains(tolist(local.running_ids), id)
  ])

  # NAT GW target: ถ้าระบุมาใช้เลย, ถ้าไม่ระบุ → ใช้ทุกตัวที่ active ใน region
  discovered_nat_ids = toset(data.aws_nat_gateways.active.ids)
  nat_ids_to_delete = length(var.nat_gateway_ids) == 0 ? local.discovered_nat_ids : toset(var.nat_gateway_ids)

  nat_ids_str    = join(" ", local.nat_ids_to_delete)
  target_ids_str = join(" ", local.target_ids)
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

resource "aws_ec2_instance_state" "target" {
  for_each    = local.target_ids
  instance_id = each.value
  state       = "stopped"

  # บังคับให้ทำหลัง NAT GW ถูกลบเสมอ
  depends_on = [null_resource.delete_nat_gateways]
}

