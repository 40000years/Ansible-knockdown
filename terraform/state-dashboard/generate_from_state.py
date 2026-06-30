import json
import sys
import os
import argparse
from datetime import datetime

def parse_tfstate(state_path):
    with open(state_path, 'r', encoding='utf-8') as f:
        tfstate = json.load(f)

    data = {
        "ec2_running": {},
        "ec2_stopped_ids": [],
        "ec2_running_detail": {},
        "ec2_grouped_by_environment": {},
        "vpc_details": {},
        "subnet_details": {},
        "route_table_details": {},
        "internet_gateways": {},
        "nat_gateways": {},
        "security_groups": {},
        "network_topology": {},
        "region": "unknown",
        "updated_at": datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    }

    resources = tfstate.get("resources", [])

    # Process all resources
    for res in resources:
        if res.get("mode") != "managed":
            continue # Only process managed resources for this example, though you could parse 'data' too

        rtype = res.get("type")
        instances = res.get("instances", [])

        for inst in instances:
            attr = inst.get("attributes", {})
            if not attr:
                continue
                
            res_id = attr.get("id")
            if not res_id:
                continue

            if rtype == "aws_vpc":
                data["vpc_details"][res_id] = {
                    "cidr_block": attr.get("cidr_block"),
                    "is_default": attr.get("is_default", False),
                    "state": attr.get("instance_tenancy", "default") # State not always in tfstate directly for VPC
                }
            elif rtype == "aws_subnet":
                data["subnet_details"][res_id] = {
                    "vpc_id": attr.get("vpc_id"),
                    "cidr_block": attr.get("cidr_block"),
                    "availability_zone": attr.get("availability_zone"),
                    "available_ips": 0, # tfstate might not track live available IPs
                    "is_public": attr.get("map_public_ip_on_launch", False)
                }
            elif rtype == "aws_internet_gateway":
                vpc_id = attr.get("vpc_id")
                if vpc_id:
                    data["internet_gateways"][vpc_id] = {
                        "igw_id": res_id,
                        "state": "available"
                    }
            elif rtype == "aws_nat_gateway":
                data["nat_gateways"][res_id] = {
                    "vpc_id": attr.get("vpc_id"),
                    "subnet_id": attr.get("subnet_id"),
                    "state": attr.get("state", "available"),
                    "connectivity_type": attr.get("connectivity_type", "public"),
                    "public_ip": attr.get("public_ip")
                }
            elif rtype == "aws_security_group":
                data["security_groups"][res_id] = {
                    "vpc_id": attr.get("vpc_id"),
                    "name": attr.get("name"),
                    "description": attr.get("description")
                }
            elif rtype == "aws_route_table":
                routes = []
                for r in attr.get("route", []):
                    dest = r.get("cidr_block") or r.get("ipv6_cidr_block") or r.get("destination_prefix_list_id") or "unknown"
                    target = r.get("gateway_id") or r.get("nat_gateway_id") or r.get("transit_gateway_id") or r.get("vpc_peering_connection_id") or r.get("network_interface_id") or r.get("instance_id")
                    if not target:
                        target = "local"
                    routes.append({"destination": dest, "target": target})
                    
                data["route_table_details"][res_id] = {
                    "vpc_id": attr.get("vpc_id"),
                    "is_main": False, # Requires parsing route_table_association
                    "associations": 0,
                    "routes": routes
                }
            elif rtype == "aws_instance":
                state = attr.get("instance_state")
                tags = attr.get("tags") or {}
                
                if state == "stopped":
                    data["ec2_stopped_ids"].append(res_id)
                elif state == "running":
                    private_ip = attr.get("private_ip")
                    public_ip = attr.get("public_ip") or "No Public IP"
                    data["ec2_running"][res_id] = {
                        "private_ip": private_ip,
                        "public_ip": public_ip
                    }
                    
                    env = tags.get("Environment", "untagged")
                    
                    data["ec2_running_detail"][res_id] = {
                        "private_ip": private_ip,
                        "public_ip": public_ip,
                        "instance_type": attr.get("instance_type"),
                        "availability_zone": attr.get("availability_zone"),
                        "key_name": attr.get("key_name", "none") or "none",
                        "name": tags.get("Name", res_id),
                        "environment": env,
                        "role": tags.get("Role", "untagged")
                    }
                    
                    if env not in data["ec2_grouped_by_environment"]:
                        data["ec2_grouped_by_environment"][env] = {
                            "instance_ids": [],
                            "private_ips": [],
                            "public_ips": []
                        }
                    
                    data["ec2_grouped_by_environment"][env]["instance_ids"].append(res_id)
                    data["ec2_grouped_by_environment"][env]["private_ips"].append(private_ip)
                    if public_ip != "No Public IP":
                        data["ec2_grouped_by_environment"][env]["public_ips"].append(public_ip)

    # Reconstruct Network Topology
    for vpc_id, vpc in data["vpc_details"].items():
        data["network_topology"][vpc_id] = {
            "cidr_block": vpc.get("cidr_block"),
            "is_default": vpc.get("is_default"),
            "subnets": {}
        }
        
    for sub_id, sub in data["subnet_details"].items():
        vpc_id = sub.get("vpc_id")
        if vpc_id in data["network_topology"]:
            data["network_topology"][vpc_id]["subnets"][sub_id] = {
                "cidr_block": sub.get("cidr_block"),
                "availability_zone": sub.get("availability_zone"),
                "is_public": sub.get("is_public"),
                "available_ips": 0
            }

    return data

def main():
    parser = argparse.ArgumentParser(description="Generate AWS Dashboard from terraform.tfstate")
    parser.add_argument("tfstate_path", help="Path to the terraform.tfstate file")
    args = parser.parse_args()

    if not os.path.exists(args.tfstate_path):
        print(f"Error: Could not find {args.tfstate_path}")
        sys.exit(1)

    print(f"Parsing state file: {args.tfstate_path}...")
    data = parse_tfstate(args.tfstate_path)

    base_dir = os.path.dirname(__file__)
    parent_dir = os.path.abspath(os.path.join(base_dir, ".."))
    
    # Save the parsed data for debugging purposes
    json_out_path = os.path.join(base_dir, "state_infrastructure_data.json")
    with open(json_out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"Exported parsed state data to {json_out_path}")

    template_path = os.path.join(parent_dir, "dashboard_template.html")
    html_out_path = os.path.join(base_dir, "state_dashboard.html")

    if not os.path.exists(template_path):
        print(f"Error: Could not find template at {template_path}")
        sys.exit(1)

    print("Injecting data into dashboard template...")
    with open(template_path, "r", encoding="utf-8") as f:
        template = f.read()

    json_payload = json.dumps(data, separators=(",", ":"), ensure_ascii=False).replace("</", "<\\/")
    html_content = template.replace("__INFRA_JSON__", json_payload)

    with open(html_out_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print("")
    print("=" * 65)
    print("  ✅ OFFLINE DASHBOARD GENERATED!")
    print(f"  👉 Open this file in your browser:")
    print(f"  {html_out_path}")
    print("=" * 65)
    print("")

if __name__ == "__main__":
    main()
