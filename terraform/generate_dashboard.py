import json
import os
import subprocess
import sys
import datetime

def log(msg):
    print(f"[Dashboard Engine] {msg}")

def main():
    base_dir = os.path.dirname(__file__)
    json_path = os.path.join(base_dir, "infrastructure_data.json")
    template_path = os.path.join(base_dir, "dashboard_template.html")
    html_path = os.path.join(base_dir, "index.html")

    if not os.path.exists(json_path):
        log(f"Error: {json_path} not found!")
        sys.exit(1)
    if not os.path.exists(template_path):
        log(f"Error: {template_path} not found!")
        sys.exit(1)

    log("Loading infrastructure data...")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Inject updated_at here so Terraform doesn't have to trigger a diff on every run
    data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    data["api_gateway_url"] = ""

    # Workaround: Terraform's data.aws_instances has a bug where it completely misses stopped instances.
    # We will fetch ALL true live EC2 instances via boto3 and fully populate the JSON before injecting.
    log("Fetching ALL live EC2 states and details via boto3...")
    try:
        import boto3
        ec2 = boto3.client('ec2')
        response = ec2.describe_instances()
        
        if "ec2_all_detail" not in data or not isinstance(data["ec2_all_detail"], dict):
            data["ec2_all_detail"] = {}
            
        patched_count = 0
        added_count = 0
        for res in response.get("Reservations", []):
            for inst in res.get("Instances", []):
                inst_id = inst.get("InstanceId")
                tags = {t.get("Key"): t.get("Value") for t in inst.get("Tags", [])}
                
                if inst_id not in data["ec2_all_detail"]:
                    data["ec2_all_detail"][inst_id] = {}
                    added_count += 1
                else:
                    patched_count += 1
                    
                info = data["ec2_all_detail"][inst_id]
                info["instance_state"] = inst.get("State", {}).get("Name", "unknown")
                info["private_ip"] = inst.get("PrivateIpAddress", "Offline")
                info["public_ip"] = inst.get("PublicIpAddress", "No Public IP")
                info["instance_type"] = inst.get("InstanceType", "unknown")
                info["availability_zone"] = inst.get("Placement", {}).get("AvailabilityZone", "unknown")
                info["key_name"] = inst.get("KeyName", "none")
                info["name"] = tags.get("Name", inst_id)
                info["environment"] = tags.get("Environment", "untagged")
                info["role"] = tags.get("Role", "untagged")
                info["is_nist_certified"] = (tags.get("NistCertified", "false").lower() == "true")
                
        # Also fix ec2_stopped_ids and ec2_running_detail just in case
        data["ec2_stopped_ids"] = [i for i, v in data["ec2_all_detail"].items() if v.get("instance_state") not in ["running", "pending"]]
        data["ec2_running_detail"] = {i: v for i, v in data["ec2_all_detail"].items() if v.get("instance_state") in ["running", "pending"]}
        
        log(f"boto3 Sync: Patched {patched_count} existing, Added {added_count} missing instances.")
    except Exception as e:
        log(f"Warning: Could not fetch true live EC2 states: {e}")



    log("Injecting data into dashboard template (client-side rendered)...")

    # The HTML is a static template that renders itself client-side.
    # We only need to inject the raw JSON payload into the data island,
    # and the browser does the rest (Three.js + SVG rendering).
    with open(template_path, "r", encoding="utf-8") as f:
        template = f.read()

    # Inject the data island. json.dumps with separators keeps it compact;
    # </script> in the data is escaped to prevent breaking out of the tag.
    json_payload = json.dumps(data, separators=(",", ":"), ensure_ascii=False).replace("</", "<\\/")

    html_content = template.replace("__INFRA_JSON__", json_payload)

    if "__INFRA_JSON__" in html_content:
        log("Error: template placeholder was not replaced!")
        sys.exit(1)

    log(f"Writing dashboard to {html_path}...")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    # Upload to S3
    bucket_name = os.environ.get("S3_BUCKET_NAME")
    dist_id = os.environ.get("CLOUDFRONT_DIST_ID")

    if not bucket_name:
        log("S3_BUCKET_NAME environment variable not set, skipping upload.")
        return

    log(f"Uploading {html_path} to S3 bucket {bucket_name}...")
    try:
        import boto3
        s3 = boto3.client('s3')
        with open(html_path, 'rb') as f:
            s3.put_object(
                Bucket=bucket_name,
                Key='index.html',
                Body=f,
                ContentType='text/html',
                CacheControl='max-age=0, no-cache, no-store, must-revalidate'
            )
        log("S3 Upload Successful ✓")
    except Exception as e:
        log(f"Error uploading to S3: {e}")
        sys.exit(1)

    # Invalidate CloudFront cache & print dashboard URL
    if dist_id:
        log(f"Invalidating CloudFront cache for distribution {dist_id}...")
        try:
            cf = boto3.client('cloudfront')
            cf.create_invalidation(
                DistributionId=dist_id,
                InvalidationBatch={
                    'Paths': {
                        'Quantity': 1,
                        'Items': ['/index.html']
                    },
                    'CallerReference': str(datetime.datetime.now().timestamp())
                }
            )
            log("CloudFront cache invalidated ✓")
        except Exception as e:
            log(f"Warning: cache invalidation failed: {e}")

        # Get CloudFront domain
        try:
            cf = boto3.client('cloudfront')
            dist = cf.get_distribution(Id=dist_id)
            cf_domain = dist['Distribution']['DomainName']
            dashboard_url = f"https://{cf_domain}"
        except Exception:
            dashboard_url = f"https://[CloudFront domain for dist {dist_id}]"

        print("")
        print("=" * 65)
        print("  ✅  DASHBOARD IS LIVE! Open in any browser:")
        print(f"  👉  {dashboard_url}")
        print("=" * 65)
        print("")
    else:
        region_name = os.environ.get("AWS_DEFAULT_REGION", "ap-southeast-1")
        print("")
        print("=" * 65)
        print("  ✅  HTML uploaded to S3:")
        print(f"  s3://{bucket_name}/index.html")
        print(f"  (Set CLOUDFRONT_DIST_ID env var for a public URL)")
        print("=" * 65)
        print("")

if __name__ == "__main__":
    main()

