# ============================================================================
# Infrastructure Dashboard: S3 + CloudFront (Full Auto)
# ============================================================================
# ต้องการสิทธิ์ IAM เพิ่มสำหรับ User Ansible (ดู iam.tf section S3Dashboard)
# ============================================================================

data "aws_caller_identity" "current" {}

locals {
  region        = var.AWS_DEFAULT_REGION != "" ? var.AWS_DEFAULT_REGION : var.aws_region
  bucket_name   = "aws-infra-dashboard-${data.aws_caller_identity.current.account_id}-${local.region}"
}

# ── 1. S3 Bucket (Private) ───────────────────────────────────────────────────
resource "aws_s3_bucket" "dashboard" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket                  = aws_s3_bucket.dashboard.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── 2. CloudFront Origin Access Control (OAC) ────────────────────────────────
resource "aws_cloudfront_origin_access_control" "dashboard" {
  name                              = "dashboard-oac-${data.aws_caller_identity.current.account_id}"
  description                       = "OAC for Infrastructure Dashboard"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── 3. CloudFront Distribution (HTTPS, Global CDN) ───────────────────────────
resource "aws_cloudfront_distribution" "dashboard" {
  origin {
    domain_name              = aws_s3_bucket.dashboard.bucket_regional_domain_name
    origin_id                = "S3-Dashboard"
    origin_access_control_id = aws_cloudfront_origin_access_control.dashboard.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Dashboard"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    # ปิด Cache ทั้งหมด — ให้อัปเดตเห็นผลทันที
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "AWS Infrastructure Dashboard" }
}

# ── 4. S3 Bucket Policy (ให้ CloudFront OAC อ่านได้เท่านั้น) ───────────────
data "aws_iam_policy_document" "s3_dashboard_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.dashboard.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.dashboard.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  policy = data.aws_iam_policy_document.s3_dashboard_policy.json
}

# ── 5. Export JSON data → trigger Python script ──────────────────────────────
resource "local_file" "infrastructure_data_json" {
  content = jsonencode({
    ec2_running                = local.running_instances
    ec2_stopped_ids            = data.aws_instances.stopped.ids
    ec2_running_detail         = local.running_instances_detail
    ec2_grouped_by_environment = local.ec2_grouped_by_environment
    vpc_details                = local.vpc_summary
    subnet_details             = local.subnet_summary
    route_table_details        = local.route_table_summary
    internet_gateways          = local.internet_gateway_summary
    nat_gateways               = local.nat_gateway_summary
    security_groups            = local.security_group_summary
    network_topology           = local.network_topology
    region                     = local.region
    updated_at                 = timestamp()
  })
  filename = "${path.module}/infrastructure_data.json"
}

resource "null_resource" "generate_and_upload_dashboard" {
  triggers = {
    data_hash     = local_file.infrastructure_data_json.content_md5
    template_hash = filesha256("${path.module}/dashboard_template.html")
    script_hash   = filesha256("${path.module}/generate_dashboard.py")
  }

  # รอให้ S3 Bucket Policy ถูก Apply ก่อนค่อยอัปโหลด HTML
  # (ป้องกัน Race Condition ที่ CloudFront อ่านไฟล์ไม่ได้เพราะ Policy ยังไม่ถูก Apply)
  depends_on = [
    aws_s3_bucket_policy.dashboard,
    aws_cloudfront_distribution.dashboard,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      AWS_DEFAULT_REGION    = local.region
      S3_BUCKET_NAME        = aws_s3_bucket.dashboard.id
      CLOUDFRONT_DIST_ID    = aws_cloudfront_distribution.dashboard.id
    }
    command = "python3 ${path.module}/generate_dashboard.py"
  }
}
