# UBUNTU26-STIG-Audit

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu 26.04 LTS](https://img.shields.io/badge/Ubuntu-26.04%20LTS-orange)](https://ubuntu.com)
[![STIG](https://img.shields.io/badge/DISA-STIG-red)](https://public.cyber.mil/stigs/)
[![goss](https://img.shields.io/badge/goss-0.4.4%2B-green)](https://github.com/goss-org/goss/)

Automated STIG Benchmark Compliance Audit for **Ubuntu 26.04 LTS** with Ansible & GOSS.

> **Ubuntu 26.04 LTS (Resolute Raccoon)** ships with **`sudo-rs`** as the default privilege escalation tool — a memory-safe Rust rewrite of the traditional C `sudo`. This audit accounts for `sudo-rs` specific behaviours and paths.

---

## Overview

This audit is a lightweight, goss-based compliance scanner for Ubuntu 26.04 LTS systems aligned with DISA STIG controls. It uses a structured directory layout that mirrors the STIG severity levels:

| Directory | Severity | Description |
|-----------|----------|-------------|
| `cat_1/`  | CAT I    | High – Immediate risk of exploitation |
| `cat_2/`  | CAT II   | Medium – Significant risk if not mitigated |
| `cat_3/`  | CAT III  | Low – Minor risk to security |

### Key Features

- ✅ Supports **Ubuntu 26.04 LTS** (Resolute Raccoon)
- ✅ Handles **`sudo-rs`** as default sudo implementation (replaces traditional C sudo)
- ✅ Supports fallback to classic **`sudo`** via `update-alternatives`
- ✅ Full STIG CAT I / II / III coverage
- ✅ Variable-driven — easily enable/disable individual controls
- ✅ Lightweight: uses the goss binary (<14 MB), no agent required
- ✅ JSON, documentation, and rspecish output formats
- ✅ Compatible with the **UBUNTU26-STIG** Ansible remediation role

---

## Requirements

- **Goss** ≥ 0.4.4 installed on the target host: https://github.com/goss-org/goss/
- **sudo** or **sudo-rs** access on the target system (some checks require root-level information)
- Ubuntu **26.04 LTS** target system

Install goss:
```bash
curl -fsSL https://goss.rocks/install | sh
```

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/UBUNTU26-STIG-Audit.git
cd UBUNTU26-STIG-Audit

# Run the audit with default settings (JSON output to stdout)
sudo ./run_audit.sh

# Run with documentation output saved to a file
sudo ./run_audit.sh -f documentation -o /tmp/stig_audit_$(hostname).txt

# Run only CAT 1 controls (edit vars/STIG.yml or pass custom vars)
sudo ./run_audit.sh -v vars/STIG.yml
```

---

## Directory Structure

```
UBUNTU26-STIG-Audit/
├── goss.yml                    # Master entry point (conditionally includes categories)
├── run_audit.sh                # Wrapper script – sets env vars and executes goss
├── vars/
│   └── STIG.yml                # Toggle individual STIG controls on/off
├── cat_1/                      # CAT I (HIGH severity) controls
│   └── UBTU-26-*.yml
├── cat_2/                      # CAT II (MEDIUM severity) controls
│   ├── UBTU-26-10xxxx/         # Account management / authentication
│   ├── UBTU-26-20xxxx/         # Audit logging
│   ├── UBTU-26-30xxxx/         # SSH / remote access
│   ├── UBTU-26-40xxxx/         # File permissions / ownership
│   ├── UBTU-26-50xxxx/         # Network / firewall
│   ├── UBTU-26-60xxxx/         # Packages / services
│   ├── UBTU-26-70xxxx/         # Kernel / boot
│   └── UBTU-26-90xxxx/         # Miscellaneous
└── cat_3/                      # CAT III (LOW severity) controls
    └── UBTU-26-*.yml
```

---

## Configuration

Edit `vars/STIG.yml` to control which checks are executed:

```yaml
# Enable/disable entire categories
ubtu26stig_cat1: true
ubtu26stig_cat2: true
ubtu26stig_cat3: true

# Enable/disable individual controls (e.g. to skip known exceptions)
ubtu26stig_100030: true
ubtu26stig_300025: false   # Skip – risk accepted via POA&M
```

### sudo-rs specific settings

```yaml
# Set to true if system uses sudo-rs (default on Ubuntu 26)
ubtu26stig_sudo_rs: true

# Set to false only if you have reverted to classic sudo via update-alternatives
ubtu26stig_classic_sudo: false
```

---

## Running via Ansible

This audit is designed to integrate with the **UBUNTU26-STIG** Ansible hardening role:

```yaml
- hosts: ubuntu26_servers
  roles:
    - role: UBUNTU26-STIG
      vars:
        run_audit: true
        audit_only: false
```

The role will:
1. **Install** goss on the target
2. **Pre-audit** the system (baseline)
3. **Remediate** STIG findings
4. **Post-audit** to validate remediation

---

## Output Formats

| Format        | Flag            | Use Case |
|---------------|-----------------|----------|
| JSON          | `-f json`       | Machine-readable, CI/CD pipelines |
| Documentation | `-f documentation` | Human-readable reports |
| rspecish      | `-f rspecish`   | Ruby RSpec-style output |
| JUnit XML     | `-f junit`      | Integration with Jenkins / SonarQube |

---

## sudo-rs Notes

Ubuntu 26.04 ships with [`sudo-rs`](https://github.com/trifectatechfoundation/sudo-rs) as the default `sudo` implementation:

- Binary: `/usr/bin/sudo` (symlinked via `update-alternatives`)
- Config: `/etc/sudoers` and `/etc/sudoers.d/` (same as classic sudo)
- Key difference: `env_reset` cannot be disabled in `sudo-rs` (enforced by design)
- `sudo-rs` binary version check: `sudo --version` output includes "sudo-rs"

To check which implementation is active:
```bash
sudo --version | grep -i 'sudo-rs\|Sudo version'
update-alternatives --display sudo
```

---

## Further Information

- [goss documentation](https://goss.readthedocs.io/en/stable/)
- [DISA STIG Standards](https://public.cyber.mil/stigs/)
- [Ubuntu Security Guide (USG)](https://ubuntu.com/security/certifications/docs/usg)
- [sudo-rs GitHub](https://github.com/trifectatechfoundation/sudo-rs)
- [Ansible-Lockdown Community](https://www.lockdownenterprise.com)
- [Discord Server](https://www.lockdownenterprise.com/discord)

---

## License

MIT License – see [LICENSE](LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
