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
        
        # Clear old mock data completely
        data["ec2_all_detail"] = {}
        
        patched_count = 0
        added_count = 0
        for res in response.get("Reservations", []):
            for inst in res.get("Instances", []):
                inst_id = inst.get("InstanceId")
                tags = {t.get("Key"): t.get("Value") for t in inst.get("Tags", [])}
                
                added_count += 1
                info = {}
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
                data["ec2_all_detail"][inst_id] = info
                
        # Update derived fields
        data["ec2_stopped_ids"] = [i for i, v in data["ec2_all_detail"].items() if v.get("instance_state") not in ["running", "pending"]]
        data["ec2_running_detail"] = {i: v for i, v in data["ec2_all_detail"].items() if v.get("instance_state") in ["running", "pending"]}
        
        # Fetch live network infrastructure to wipe out old cache
        vpcs = ec2.describe_vpcs().get('Vpcs', [])
        data["vpc_details"] = {v['VpcId']: {'cidr_block': v.get('CidrBlock'), 'is_default': v.get('IsDefault')} for v in vpcs}
        
        subnets = ec2.describe_subnets().get('Subnets', [])
        data["subnet_details"] = {s['SubnetId']: {'vpc_id': s.get('VpcId'), 'cidr_block': s.get('CidrBlock'), 'availability_zone': s.get('AvailabilityZone')} for s in subnets}
        
        sgs = ec2.describe_security_groups().get('SecurityGroups', [])
        data["security_groups"] = {sg['GroupId']: {'vpc_id': sg.get('VpcId'), 'name': sg.get('GroupName'), 'description': sg.get('Description')} for sg in sgs}
        
        igws = ec2.describe_internet_gateways().get('InternetGateways', [])
        data["internet_gateways"] = {}
        for i in igws:
            for attach in i.get('Attachments', []):
                data["internet_gateways"][attach.get('VpcId')] = {'igw_id': i['InternetGatewayId'], 'state': attach.get('State')}
                
        nats = ec2.describe_nat_gateways().get('NatGateways', [])
        data["nat_gateways"] = {}
        for n in nats:
            pub, priv = "", ""
            for a in n.get('NatGatewayAddresses', []):
                pub = a.get('PublicIp', '')
                priv = a.get('PrivateIp', '')
                break
            data["nat_gateways"][n['NatGatewayId']] = {
                'vpc_id': n.get('VpcId'), 'subnet_id': n.get('SubnetId'), 'state': n.get('State'),
                'public_ip': pub, 'private_ip': priv, 'connectivity_type': n.get('ConnectivityType', 'unknown')
            }
            
        rts = ec2.describe_route_tables().get('RouteTables', [])
        data["route_table_details"] = {}
        for rt in rts:
            routes = []
            for r in rt.get('Routes', []):
                target = r.get('GatewayId') or r.get('NatGatewayId') or r.get('InstanceId') or r.get('NetworkInterfaceId') or 'local'
                routes.append({'destination': r.get('DestinationCidrBlock', r.get('DestinationIpv6CidrBlock', '')), 'target': target})
            data["route_table_details"][rt['RouteTableId']] = {
                'vpc_id': rt.get('VpcId'),
                'is_main': any(a.get('Main', False) for a in rt.get('Associations', [])),
                'associations': len(rt.get('Associations', [])),
                'routes': routes
            }
        
        # Rebuild topology
        topo = {}
        for v in vpcs:
            topo[v['VpcId']] = {'cidr_block': v.get('CidrBlock'), 'is_default': v.get('IsDefault'), 'subnets': {}}
        for s in subnets:
            vid = s.get('VpcId')
            if vid in topo:
                topo[vid]['subnets'][s['SubnetId']] = {'availability_zone': s.get('AvailabilityZone'), 'cidr_block': s.get('CidrBlock')}
        data["network_topology"] = topo
        
        log(f"boto3 Sync: Fetched {added_count} live EC2 instances and all related networking components.")
    except Exception as e:
        log(f"Warning: Could not fetch true live EC2 states: {e}")

    # =========================================================================
    # Azure Data Sync — only runs if Azure credentials are present
    # =========================================================================
    log("Checking Azure credentials for Multi-Cloud sync...")
    azure_creds = {
        "subscription_id": os.environ.get("AZURE_SUBSCRIPTION_ID", ""),
        "client_id": os.environ.get("AZURE_CLIENT_ID", ""),
        "client_secret": os.environ.get("AZURE_CLIENT_SECRET", ""),
        "tenant_id": os.environ.get("AZURE_TENANT_ID", ""),
    }

    if all(azure_creds.values()):
        log("Azure credentials found — fetching Azure resources...")
        try:
            from azure.identity import ClientSecretCredential
            from azure.mgmt.compute import ComputeManagementClient
            from azure.mgmt.network import NetworkManagementClient

            credential = ClientSecretCredential(
                tenant_id=azure_creds["tenant_id"],
                client_id=azure_creds["client_id"],
                client_secret=azure_creds["client_secret"],
            )
            sub_id = azure_creds["subscription_id"]
            compute_client = ComputeManagementClient(credential, sub_id)
            network_client = NetworkManagementClient(credential, sub_id)

            # ---- VMs ----
            azure_vms = {}
            for vm in compute_client.virtual_machines.list_all():
                rg = vm.id.split("/")[4]
                try:
                    inst_view = compute_client.virtual_machines.instance_view(rg, vm.name)
                    statuses = inst_view.statuses or []
                    state = "unknown"
                    for s in statuses:
                        if s.code and s.code.startswith("PowerState/"):
                            state = s.code.split("/")[1]
                    # Get private IP from NIC
                    private_ip = ""
                    if vm.network_profile and vm.network_profile.network_interfaces:
                        for nic_ref in vm.network_profile.network_interfaces:
                            nic_name = nic_ref.id.split("/")[-1]
                            nic_rg = nic_ref.id.split("/")[4]
                            nic = network_client.network_interfaces.get(nic_rg, nic_name)
                            for ip_config in nic.ip_configurations or []:
                                if ip_config.private_ip_address:
                                    private_ip = ip_config.private_ip_address
                                    break
                except Exception:
                    state = "unknown"
                    private_ip = ""
                tags = vm.tags or {}
                azure_vms[vm.id] = {
                    "name": vm.name,
                    "resource_group": rg,
                    "location": vm.location,
                    "vm_size": vm.hardware_profile.vm_size if vm.hardware_profile else "unknown",
                    "state": state,
                    "private_ip": private_ip,
                    "os_type": vm.storage_profile.os_disk.os_type if vm.storage_profile else "unknown",
                    "tags": tags,
                }
            data["azure_vms"] = azure_vms
            log(f"Azure: fetched {len(azure_vms)} VMs")

            # ---- VNets ----
            azure_vnets = {}
            for vnet in network_client.virtual_networks.list_all():
                rg = vnet.id.split("/")[4]
                subnets_info = {}
                for subnet in vnet.subnets or []:
                    subnets_info[subnet.name] = {
                        "id": subnet.id,
                        "address_prefix": subnet.address_prefix,
                    }
                azure_vnets[vnet.id] = {
                    "name": vnet.name,
                    "resource_group": rg,
                    "location": vnet.location,
                    "address_space": vnet.address_space.address_prefixes if vnet.address_space else [],
                    "subnets": subnets_info,
                }
            data["azure_vnets"] = azure_vnets
            log(f"Azure: fetched {len(azure_vnets)} VNets")

            # ---- VPN Connections ----
            azure_vpn_connections = {}
            for conn in network_client.virtual_network_gateway_connections.list_all():
                rg = conn.id.split("/")[4]
                azure_vpn_connections[conn.name] = {
                    "id": conn.id,
                    "resource_group": rg,
                    "location": conn.location,
                    "connection_type": conn.connection_type,
                    "connection_status": conn.connection_status,
                    "ingress_bytes": conn.ingress_bytes_transferred or 0,
                    "egress_bytes": conn.egress_bytes_transferred or 0,
                }
            data["azure_vpn_connections"] = azure_vpn_connections
            log(f"Azure: fetched {len(azure_vpn_connections)} VPN connections")

            data["azure_configured"] = True
            data["azure_subscription_id"] = sub_id

        except ImportError:
            log("Warning: azure-identity / azure-mgmt-compute / azure-mgmt-network not installed. Run: pip install azure-identity azure-mgmt-compute azure-mgmt-network")
            data.setdefault("azure_configured", False)
        except Exception as e:
            log(f"Warning: Could not fetch Azure data: {e}")
            data.setdefault("azure_configured", False)
    else:
        log("Azure credentials not set — skipping Azure sync (set AZURE_SUBSCRIPTION_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)")
        data.setdefault("azure_configured", False)
        data.setdefault("azure_vms", {})
        data.setdefault("azure_vnets", {})
        data.setdefault("azure_vpn_connections", {})


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

