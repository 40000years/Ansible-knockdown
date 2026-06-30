import json
import os
import subprocess
import sys

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
        subprocess.run([
            "aws", "s3", "cp", html_path, f"s3://{bucket_name}/index.html",
            "--content-type", "text/html",
            "--cache-control", "max-age=0, no-cache, no-store, must-revalidate"
        ], check=True)
        log("S3 Upload Successful ✓")
    except subprocess.CalledProcessError as e:
        log(f"Error uploading to S3: {e}")
        sys.exit(1)

    # Invalidate CloudFront cache & print dashboard URL
    dist_id = os.environ.get("CLOUDFRONT_DIST_ID", "")
    if dist_id:
        log(f"Invalidating CloudFront cache for distribution {dist_id}...")
        try:
            subprocess.run([
                "aws", "cloudfront", "create-invalidation",
                "--distribution-id", dist_id,
                "--paths", "/index.html"
            ], check=True, capture_output=True)
            log("CloudFront cache invalidated ✓")
        except subprocess.CalledProcessError as e:
            log(f"Warning: cache invalidation failed: {e}")

        # Get CloudFront domain
        try:
            result = subprocess.run([
                "aws", "cloudfront", "get-distribution",
                "--id", dist_id,
                "--query", "Distribution.DomainName",
                "--output", "text"
            ], check=True, capture_output=True, text=True)
            cf_domain = result.stdout.strip()
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

