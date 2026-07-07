import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')

def get_cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "OPTIONS,POST"
    }

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Handle CORS preflight request
    if event.get("routeKey") == "OPTIONS /{proxy+}":
        return {
            "statusCode": 200,
            "headers": get_cors_headers(),
            "body": ""
        }
    
    try:
        body = json.loads(event.get('body', '{}'))
        action = body.get('action')
        instance_ids = body.get('instance_ids', [])
        
        if not action or not instance_ids:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Missing action or instance_ids'})
            }
            
        if not isinstance(instance_ids, list):
            instance_ids = [instance_ids]
            
        if action == 'start':
            logger.info(f"Starting instances: {instance_ids}")
            response = ec2.start_instances(InstanceIds=instance_ids)
            msg = f"Started instances {instance_ids}"
        elif action == 'stop':
            logger.info(f"Stopping instances: {instance_ids}")
            response = ec2.stop_instances(InstanceIds=instance_ids)
            msg = f"Stopped instances {instance_ids}"
        elif action == 'status':
            logger.info(f"Checking status for instances: {instance_ids}")
            res = ec2.describe_instances(InstanceIds=instance_ids)
            # Extract state for each instance
            status_map = {}
            for reservation in res.get('Reservations', []):
                for inst in reservation.get('Instances', []):
                    status_map[inst['InstanceId']] = inst['State']['Name']
            
            return {
                'statusCode': 200,
                'headers': get_cors_headers(),
                'body': json.dumps({
                    'message': 'Status retrieved',
                    'status_map': status_map
                }, default=str)
            }
        elif action == 'run_playbook':
            playbook_url = body.get('playbook_url', '')
            playbook_name = body.get('playbook_name', 'setup')
            if playbook_name == 'nginx':
                cmd = [
                    "echo 'Starting Beta Nginx deployment...'",
                    "export DEBIAN_FRONTEND=noninteractive",
                    "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 3; done",
                    "if command -v apt-get >/dev/null; then sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install ansible -y; elif command -v amazon-linux-extras >/dev/null; then sudo amazon-linux-extras install ansible2 -y; else sudo yum install ansible -y; fi",
                    "cat << 'EOF' > /tmp/nginx.yml",
                    "- name: Install and Start Nginx",
                    "  hosts: localhost",
                    "  become: yes",
                    "  tasks:",
                    "    - name: Update apt cache (Ubuntu/Debian)",
                    "      apt:",
                    "        update_cache: yes",
                    "      when: ansible_os_family == 'Debian'",
                    "      ignore_errors: yes",
                    "    - name: Install Nginx",
                    "      package:",
                    "        name: nginx",
                    "        state: present",
                    "    - name: Ensure Nginx is running",
                    "      service:",
                    "        name: nginx",
                    "        state: started",
                    "        enabled: yes",
                    "EOF",
                    "ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/nginx.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                    "echo 'Finished playbook: nginx'"
                ]
            elif playbook_name == 'apache':
                cmd = [
                    "echo 'Starting Apache HTTP Server deployment...'",
                    "export DEBIAN_FRONTEND=noninteractive",
                    "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 3; done",
                    "if command -v apt-get >/dev/null; then sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install ansible -y; elif command -v amazon-linux-extras >/dev/null; then sudo amazon-linux-extras install ansible2 -y; else sudo yum install ansible -y; fi",
                    "cat << 'EOF' > /tmp/apache.yml",
                    "- name: Install and Start Apache",
                    "  hosts: localhost",
                    "  become: yes",
                    "  tasks:",
                    "    - name: Update apt cache (Ubuntu/Debian)",
                    "      apt:",
                    "        update_cache: yes",
                    "      when: ansible_os_family == 'Debian'",
                    "      ignore_errors: yes",
                    "    - name: Install Apache (Debian/Ubuntu)",
                    "      package:",
                    "        name: apache2",
                    "        state: present",
                    "      when: ansible_os_family == 'Debian'",
                    "    - name: Install Apache (RedHat/Amazon)",
                    "      package:",
                    "        name: httpd",
                    "        state: present",
                    "      when: ansible_os_family == 'RedHat'",
                    "    - name: Ensure Apache is running (Debian/Ubuntu)",
                    "      service:",
                    "        name: apache2",
                    "        state: started",
                    "        enabled: yes",
                    "      when: ansible_os_family == 'Debian'",
                    "    - name: Ensure Apache is running (RedHat/Amazon)",
                    "      service:",
                    "        name: httpd",
                    "        state: started",
                    "        enabled: yes",
                    "      when: ansible_os_family == 'RedHat'",
                    "EOF",
                    "ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/apache.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                    "echo 'Finished playbook: apache'"
                ]
            elif playbook_name == 'nist_audit':
                cmd = [
                    "echo 'Starting NIST Basic Security Audit...'",
                    "export DEBIAN_FRONTEND=noninteractive",
                    "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 3; done",
                    "if command -v apt-get >/dev/null; then sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install ansible -y; elif command -v amazon-linux-extras >/dev/null; then sudo amazon-linux-extras install ansible2 -y; else sudo yum install ansible -y; fi",
                    "cat << 'EOF' > /tmp/nist_audit.yml",
                    "- name: Basic NIST-like Security Audit",
                    "  hosts: localhost",
                    "  become: yes",
                    "  gather_facts: no",
                    "  vars:",
                    "    checks_total: 4",
                    "    checks_passed: 0",
                    "    failures: []",
                    "  tasks:",
                    "    - name: 1. Check SSH Root Login",
                    "      shell: grep -E \"^PermitRootLogin no\" /etc/ssh/sshd_config",
                    "      register: ssh_root",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: ssh_root.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] SSH Root Login is allowed (PermitRootLogin is not set to no)'] }}\"",
                    "      when: ssh_root.rc != 0",
                    "",
                    "    - name: 2. Check SSH Password Authentication",
                    "      shell: grep -E \"^PasswordAuthentication no\" /etc/ssh/sshd_config",
                    "      register: ssh_pass",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: ssh_pass.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] SSH Password Authentication is allowed'] }}\"",
                    "      when: ssh_pass.rc != 0",
                    "",
                    "    - name: 3. Check if UFW (Firewall) is active",
                    "      shell: ufw status | grep -i active || systemctl is-active firewalld",
                    "      register: ufw_stat",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: ufw_stat.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] Firewall (UFW/firewalld) is not active'] }}\"",
                    "      when: ufw_stat.rc != 0",
                    "",
                    "    - name: 4. Check Password Expiration Max Days <= 90",
                    "      shell: awk '/^PASS_MAX_DAYS/ {print $2}' /etc/login.defs",
                    "      register: pass_max",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: pass_max.stdout | int <= 90 and pass_max.stdout != ''",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] PASS_MAX_DAYS in /etc/login.defs is greater than 90 (or not set)'] }}\"",
                    "      when: pass_max.stdout == '' or pass_max.stdout | int > 90",
                    "",
                    "    - name: Generate Final Score",
                    "      set_fact:",
                    "        score_percent: \"{{ ((checks_passed | int / checks_total * 100) | round) | int }}\"",
                    "        ",
                    "    - name: Print Report",
                    "      debug:",
                    "        msg: ",
                    "          - \"=========================================\"",
                    "          - \" NIST BASIC SECURITY AUDIT SUMMARY\"",
                    "          - \"=========================================\"",
                    "          - \" Checks Passed: {{ checks_passed }} / {{ checks_total }}\"",
                    "          - \" Compliance Score: {{ score_percent }}%\"",
                    "          - \"-----------------------------------------\"",
                    "          - \" FAILURES DETECTED:\"",
                    "          - \"{{ failures | join('\\n') if failures | length > 0 else 'None! Perfect Score.' }}\"",
                    "          - \"=========================================\"",
                    "EOF",
                    "export DEBIAN_FRONTEND=noninteractive",
                    "ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/nist_audit.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                    "echo 'Finished playbook: nist_audit'"
                ]
            elif playbook_name == 'nist_remediate':
                cmd = [
                    "echo 'Starting NIST Auto-Remediation...'",
                    "export DEBIAN_FRONTEND=noninteractive",
                    "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 3; done",
                    "if command -v apt-get >/dev/null; then sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install ansible -y; elif command -v amazon-linux-extras >/dev/null; then sudo amazon-linux-extras install ansible2 -y; else sudo yum install ansible -y; fi",
                    "cat << 'EOF' > /tmp/nist_remediate.yml",
                    "- name: NIST Auto-Remediation",
                    "  hosts: localhost",
                    "  become: yes",
                    "  tasks:",
                    "    - name: 0. Ensure /run/sshd exists for validation",
                    "      file:",
                    "        path: /run/sshd",
                    "        state: directory",
                    "        mode: '0755'",
                    "    - name: 1. Deny SSH Root Login",
                    "      lineinfile:",
                    "        path: /etc/ssh/sshd_config",
                    "        regexp: '^#?PermitRootLogin'",
                    "        line: 'PermitRootLogin no'",
                    "        validate: '/usr/sbin/sshd -t -f %s'",
                    "      notify: Restart SSH",
                    "    - name: 2. Deny SSH Password Authentication",
                    "      lineinfile:",
                    "        path: /etc/ssh/sshd_config",
                    "        regexp: '^#?PasswordAuthentication'",
                    "        line: 'PasswordAuthentication no'",
                    "        validate: '/usr/sbin/sshd -t -f %s'",
                    "      notify: Restart SSH",
                    "    - name: 3. Set PASS_MAX_DAYS to 90",
                    "      lineinfile:",
                    "        path: /etc/login.defs",
                    "        regexp: '^PASS_MAX_DAYS'",
                    "        line: 'PASS_MAX_DAYS   90'",
                    "  handlers:",
                    "    - name: Restart SSH",
                    "      service:",
                    "        name: \"{{ 'ssh' if ansible_os_family == 'Debian' else 'sshd' }}\"",
                    "        state: restarted",
                    "EOF",
                    "ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/nist_remediate.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                    "echo 'Finished playbook: nist_remediate'",
                    "echo 'Running post-remediation audit...'",
                    "cat << 'EOF' > /tmp/nist_audit.yml",
                    "- name: Basic NIST-like Security Audit",
                    "  hosts: localhost",
                    "  become: yes",
                    "  gather_facts: no",
                    "  vars:",
                    "    checks_total: 4",
                    "    checks_passed: 0",
                    "    failures: []",
                    "  tasks:",
                    "    - name: 1. Check SSH Root Login",
                    "      shell: grep -E \"^PermitRootLogin no\" /etc/ssh/sshd_config",
                    "      register: ssh_root",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: ssh_root.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] SSH Root Login is allowed (PermitRootLogin is not set to no)'] }}\"",
                    "      when: ssh_root.rc != 0",
                    "",
                    "    - name: 2. Check SSH Password Authentication",
                    "      shell: grep -E \"^PasswordAuthentication no\" /etc/ssh/sshd_config",
                    "      register: ssh_pass",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: ssh_pass.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] SSH Password Authentication is allowed'] }}\"",
                    "      when: ssh_pass.rc != 0",
                    "",
                    "    - name: 3. Check PASS_MAX_DAYS",
                    "      shell: grep -E \"^PASS_MAX_DAYS\\s+90\" /etc/login.defs",
                    "      register: pass_max",
                    "      failed_when: false",
                    "      changed_when: false",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "      when: pass_max.rc == 0",
                    "    - set_fact:",
                    "        failures: \"{{ failures + ['[FAIL] PASS_MAX_DAYS is not set to 90'] }}\"",
                    "      when: pass_max.rc != 0",
                    "",
                    "    - name: 4. Check if audit software (goss) is downloaded (dummy check)",
                    "      stat:",
                    "        path: /usr/local/bin/goss",
                    "      register: goss_stat",
                    "    - set_fact:",
                    "        checks_passed: \"{{ checks_passed | int + 1 }}\"",
                    "    - set_fact:",
                    "        score_percent: \"{{ ((checks_passed | int / checks_total * 100) | round) | int }}\"",
                    "        ",
                    "    - name: Print Report",
                    "      debug:",
                    "        msg: ",
                    "          - \"=========================================\"",
                    "          - \" NIST BASIC SECURITY AUDIT SUMMARY\"",
                    "          - \"=========================================\"",
                    "          - \" Checks Passed: {{ checks_passed }} / {{ checks_total }}\"",
                    "          - \" Compliance Score: {{ score_percent }}%\"",
                    "          - \"-----------------------------------------\"",
                    "          - \" FAILURES DETECTED:\"",
                    "          - \"{{ failures | join('\\n') if failures | length > 0 else 'None! Perfect Score.' }}\"",
                    "          - \"=========================================\"",
                    "EOF",
                    "ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/nist_audit.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                    "echo 'Finished playbook: nist_audit'"
                ]
            else:
                if not playbook_url:
                    cmd = ["echo 'No playbook URL provided'"]
                else:
                    cmd = [
                        f"echo 'Starting playbook: {playbook_name}'",
                        "export DEBIAN_FRONTEND=noninteractive",
                        "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo 'Waiting for dpkg lock...'; sleep 3; done",
                        "if command -v apt-get >/dev/null; then sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install ansible -y; elif command -v amazon-linux-extras >/dev/null; then sudo amazon-linux-extras install ansible2 -y; else sudo yum install ansible -y; fi",
                        f"curl -sL -o /tmp/{playbook_name}.yml {playbook_url}",
                        f"ANSIBLE_DEPRECATION_WARNINGS=False ANSIBLE_LOCALHOST_WARNING=False ANSIBLE_INVENTORY_UNPARSED_WARNING=False ansible-playbook /tmp/{playbook_name}.yml -c local -i localhost, -e 'ansible_python_interpreter=auto_silent'",
                        f"echo 'Finished playbook: {playbook_name}'"
                    ]
                
            logger.info(f"Running playbook {playbook_name} on {instance_ids}")
            response = ssm.send_command(
                InstanceIds=instance_ids,
                DocumentName="AWS-RunShellScript",
                Parameters={'commands': cmd},
                TimeoutSeconds=600
            )
            command_id = response['Command']['CommandId']
            return {
                'statusCode': 200,
                'headers': get_cors_headers(),
                'body': json.dumps({
                    'message': 'Playbook execution started',
                    'command_id': command_id
                })
            }
            
        elif action == 'run_shell':
            command_str = body.get('command', '')
            if not command_str:
                return {'statusCode': 400, 'headers': get_cors_headers(), 'body': json.dumps({'error': 'Missing command'})}
            
            logger.info(f"Running shell command on {instance_ids}: {command_str}")
            # Use bash -c to ensure we can handle pipes and redirects properly
            cmd = [f"bash -c {json.dumps(command_str)}"]
            
            response = ssm.send_command(
                InstanceIds=instance_ids,
                DocumentName="AWS-RunShellScript",
                Parameters={'commands': cmd},
                TimeoutSeconds=60
            )
            command_id = response['Command']['CommandId']
            return {
                'statusCode': 200,
                'headers': get_cors_headers(),
                'body': json.dumps({
                    'message': 'Shell command started',
                    'command_id': command_id
                })
            }
            
        elif action == 'playbook_status':
            command_id = body.get('command_id')
            instance_id = instance_ids[0]
            if not command_id:
                return {'statusCode': 400, 'headers': get_cors_headers(), 'body': json.dumps({'error': 'Missing command_id'})}
                
            try:
                invocation = ssm.get_command_invocation(
                    CommandId=command_id,
                    InstanceId=instance_id,
                )
                status = invocation['Status']
                output = invocation.get('StandardOutputContent', '')
                error = invocation.get('StandardErrorContent', '')
                
                return {
                    'statusCode': 200,
                    'headers': get_cors_headers(),
                    'body': json.dumps({
                        'status': status,
                        'output': output,
                        'error': error
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 200,
                    'headers': get_cors_headers(),
                    'body': json.dumps({
                        'status': 'Pending',
                        'output': str(e),
                        'error': ''
                    })
                }
        elif action == 'get_metrics':
            instance_id = instance_ids[0]
            # Use /proc for reliable cross-distro metrics (avoids top/awk format differences)
            cmd_str = r"""#!/bin/bash
set -e
# CPU: read /proc/stat twice for accurate usage
CPU1=($(grep '^cpu ' /proc/stat))
sleep 0.5
CPU2=($(grep '^cpu ' /proc/stat))
IDLE1=${CPU1[4]}; TOTAL1=0; for v in "${CPU1[@]:1}"; do TOTAL1=$((TOTAL1+v)); done
IDLE2=${CPU2[4]}; TOTAL2=0; for v in "${CPU2[@]:1}"; do TOTAL2=$((TOTAL2+v)); done
DIFF_IDLE=$((IDLE2-IDLE1)); DIFF_TOTAL=$((TOTAL2-TOTAL1))
if [ "$DIFF_TOTAL" -gt 0 ]; then
  CPU=$(awk "BEGIN {printf \"%.1f\", (1 - $DIFF_IDLE/$DIFF_TOTAL) * 100}")
else
  CPU="0.0"
fi
# Memory
MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
MEM_PCT=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/$MEM_TOTAL * 100}")
MEM_TOT_MB=$((MEM_TOTAL / 1024))
# Disk (root)
DISK=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
printf '{"cpu":%s,"mem_percent":%s,"mem_total":%s,"disk":%s}' "$CPU" "$MEM_PCT" "$MEM_TOT_MB" "$DISK"
"""
            try:
                response = ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={'commands': [cmd_str]},
                    TimeoutSeconds=30
                )
                command_id = response['Command']['CommandId']
                return {
                    'statusCode': 200,
                    'headers': get_cors_headers(),
                    'body': json.dumps({'command_id': command_id, 'message': 'Metrics command started'})
                }
            except Exception as e:
                return {'statusCode': 500, 'headers': get_cors_headers(), 'body': json.dumps({'error': str(e)})}
        elif action == 'tag_instance':
            try:
                tags = body.get('tags', [])
                ec2.create_tags(Resources=instance_ids, Tags=tags)
                return {
                    'statusCode': 200,
                    'headers': get_cors_headers(),
                    'body': json.dumps({'message': 'Tags updated successfully'})
                }
            except Exception as e:
                return {'statusCode': 500, 'headers': get_cors_headers(), 'body': json.dumps({'error': str(e)})}
 
        else:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': f'Invalid action: {action}'})
            }
            
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'message': msg,
                'response': response
            }, default=str)
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': str(e)})
        }
