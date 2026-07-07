#!/bin/bash
set -e

echo "============================================"
echo " Fast UI Update Task"
echo "============================================"

# Read outputs from Terraform state
BUCKET_NAME=$(tofu output -raw dashboard_bucket 2>/dev/null || terraform output -raw dashboard_bucket)
DIST_ID=$(tofu output -raw dashboard_cloudfront_id 2>/dev/null || terraform output -raw dashboard_cloudfront_id)

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Could not retrieve S3 bucket name from Terraform outputs."
  echo "Make sure you have run 'terraform apply' or 'tofu apply' at least once."
  exit 1
fi

export S3_BUCKET_NAME="$BUCKET_NAME"
export CLOUDFRONT_DIST_ID="$DIST_ID"
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"ap-southeast-1"}

echo "Using S3 Bucket: $S3_BUCKET_NAME"
if [ -n "$CLOUDFRONT_DIST_ID" ]; then
  echo "Using CloudFront ID: $CLOUDFRONT_DIST_ID"
fi

# Run the python script to regenerate HTML and upload it
python3 generate_dashboard.py
