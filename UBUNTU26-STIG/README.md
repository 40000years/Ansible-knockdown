# UBUNTU26-STIG

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu 26.04 LTS](https://img.shields.io/badge/Ubuntu-26.04%20LTS-orange)](https://ubuntu.com)

Automated STIG Benchmark Compliance Remediation for **Ubuntu 26.04 LTS** (Resolute Raccoon) with Ansible.

This role configures an Ubuntu 26 system to comply with DISA STIG requirements. It is a sibling to the [UBUNTU26-STIG-Audit](../UBUNTU26-STIG-Audit) project and integrates seamlessly with it to provide automated pre-remediation and post-remediation auditing.

> **Note on sudo-rs:** Ubuntu 26.04 ships with `sudo-rs` (a memory-safe Rust rewrite of sudo) as the default privilege escalation tool. This role automatically detects `sudo-rs` and applies compatible configurations.

---

## 🚀 Quick Start

1. Clone both the Remediation Role and the Audit repository into your workspace:
   ```bash
   git clone https://github.com/your-org/UBUNTU26-STIG-Audit.git
   git clone https://github.com/your-org/UBUNTU26-STIG.git
   ```

2. Run the provided example playbook (`site.yml`):
   ```bash
   ansible-playbook -i your_inventory site.yml -K
   ```

## ⚙️ Configuration

All configurations are managed via `defaults/main.yml`. You can override these variables in your playbook or inventory.

### Auditing Integration

To automatically run a STIG audit before and after remediation, set:
```yaml
run_audit: true
```
The role will install `goss`, copy the audit rules to the target, run the pre-audit, apply fixes, run the post-audit, and fetch the JSON reports back to the Ansible control node.

### Disabling Controls

You can disable entire categories or individual controls:
```yaml
ubtu26stig_cat3: false       # Disable all LOW severity controls
ubtu26stig_100040: false     # Allow direct root login (skip this control)
```

## ⚠️ Cautions

- **Testing is critical!** This role makes significant changes to sshd, pam, kernel parameters, and auditd which can break access or functionality if not tested in your specific environment.
- Setting `ubtu26stig_allow_reboot: true` permits the role to restart the system automatically if kernel parameters demand it.
- **Check Mode (`--check`)** is supported but may show failures if prerequisite packages are not installed yet.

## 📝 License

MIT
