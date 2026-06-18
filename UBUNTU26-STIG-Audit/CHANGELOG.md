# Changelog

All notable changes to **UBUNTU26-STIG-Audit** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.0.0] - 2026-06-18

### 🎉 Initial Release — Ubuntu 26.04 LTS (Resolute Raccoon)

This is the first release of UBUNTU26-STIG-Audit, built from the ground up to support **Ubuntu 26.04 LTS** and its new default privilege escalation implementation: **`sudo-rs`** (a memory-safe Rust rewrite of the traditional C `sudo`).

---

### ✅ Added

#### Core Infrastructure
- `goss.yml` — Master entry point with conditional category inclusion via template variables
- `run_audit.sh` — Audit runner script with:
  - Automatic **sudo-rs vs classic sudo** detection (sets `ubtu26stig_sudo_rs` automatically)
  - Minimum goss version check (≥ 0.4.4)
  - OS version validation (warns if not Ubuntu 26.04)
  - Support for `-f json|documentation|rspecish|junit` output formats
  - JUnit XML output for CI/CD pipeline integration
  - `-m` flag for max concurrent goss processes
  - Temporary merged vars file creation (auto-cleaned on exit)
- `vars/STIG.yml` — Full variable file with all control toggles

#### CAT I (HIGH Severity) Controls — `cat_1/`
| File | Controls |
|------|----------|
| `UBTU-26-100030.yml` | Null/blank password accounts |
| `UBTU-26-100040.yml` | Direct root login prevention |
| `UBTU-26-100800_100810.yml` | Ctrl-Alt-Delete disabled & masked |
| `UBTU-26-102000.yml` | OpenSSL / DoD-approved encryption |
| `UBTU-26-300022_300031.yml` | SSH: PermitRootLogin, KexAlgorithms, MACs, Ciphers, PermitEmptyPasswords, PermitUserEnvironment |
| `UBTU-26-400370.yml` | rsh-server, rsh-client, telnetd packages removed |
| `UBTU-26-600030.yml` | AIDE installed and daily cron configured |
| `UBTU-26-700400_700410.yml` | ASLR (randomize_va_space=2) and ptrace_scope |

#### CAT II (MEDIUM Severity) Controls — `cat_2/`
| Subdirectory | Controls Covered |
|--------------|-----------------|
| `UBTU-26-10xxxx/` | Password quality (pwquality), length, complexity, history, lockout; **sudo-rs package check**; NOPASSWD enforcement; sudo logging; env_reset; use_pty |
| `UBTU-26-20xxxx/` | auditd service, sudo-rs auditing, sudoers auditing, passwd/shadow auditing, log size, disk action, module loading, immutable rules, log directory permissions |
| `UBTU-26-30xxxx/` | Full SSH daemon controls (Protocol, LogLevel, X11, MaxAuthTries, KnownHosts, HostbasedAuth, Rhosts, ClientAlive, PubkeyAuth, PasswordAuth, Banner, AllowTcpForwarding, PrintLastLog, sshd_config permissions) |
| `UBTU-26-40xxxx/` | /etc/passwd, /etc/shadow, /etc/group, /etc/gshadow permissions; /etc/sudoers ownership; world-writable dirs; unowned files; SUID/SGID review; cron.allow; umask |
| `UBTU-26-50xxxx/` | UFW firewall, IPv4 forwarding, ICMP redirects, reverse path filtering, SYN cookies |
| `UBTU-26-60xxxx/` | Remove telnet/NIS/tftp; disable Avahi/CUPS; AppArmor enforce mode; automatic security updates |
| `UBTU-26-70xxxx/` | dmesg_restrict, kptr_restrict, GRUB password, Secure Boot, perf_event_paranoid, BPF restriction, SysRq disabled, NX bit |
| `UBTU-26-90xxxx/` | DoD MOTD/issue.net banners, core dump restriction, NTP synchronization |

#### CAT III (LOW Severity) Controls — `cat_3/`
- `/etc/issue` warning banner check
- GUI lock screen (conditional on `ubtu26stig_gui`)
- Remote syslog/audit forwarding (rsyslog / auditd remote_server)
- SSH `authorized_keys` file permissions
- World-readable files in home directories

---

### 🔄 Changed from UBUNTU24-STIG-Audit

| Item | Ubuntu 24 | Ubuntu 26 |
|------|-----------|-----------|
| Benchmark prefix | `UBTU-24-` | `UBTU-26-` |
| Variable prefix | `ubtu24stig_` | `ubtu26stig_` |
| sudo implementation | Classic sudo (C) | **sudo-rs** (Rust) — default |
| sudo package | `sudo` | `sudo-rs` |
| New variable | — | `ubtu26stig_sudo_rs: true` |
| New variable | — | `ubtu26stig_classic_sudo: false` |
| Kernel controls | Basic | Extended (BPF, SysRq, kptr, dmesg, perf) |
| Output formats | json, documentation, rspecish | + **junit** |
| OS version check | Ubuntu 24.04 | Ubuntu 26.04 |

---

### 🔐 sudo-rs Specific Notes

Ubuntu 26.04 LTS ships with [`sudo-rs`](https://github.com/trifectatechfoundation/sudo-rs) as the default `sudo` implementation:

- **Package**: `sudo-rs` (provides `/usr/bin/sudo` via `update-alternatives`)
- **Config**: `/etc/sudoers` and `/etc/sudoers.d/` (compatible with classic format)
- **Key behavior**: `env_reset` is **always enforced** and cannot be disabled
- **Audit**: `sudo-rs` still invokes via `/usr/bin/sudo` path — existing auditd rules for `/usr/bin/sudo` remain valid

Controls updated for sudo-rs:
- `UBTU-26-100820` — Verifies `sudo-rs` package and active binary implementation
- `UBTU-26-100830` — Confirms no `NOPASSWD` in sudoers
- `UBTU-26-100840` — Verifies sudo command logging (compatible with sudo-rs)
- `UBTU-26-100850` — `env_reset` enforcement (note: sudo-rs enforces this regardless of sudoers setting)
- `UBTU-26-100860` — `use_pty` requirement
- `run_audit.sh` — Automatically detects sudo-rs and injects detection variable into goss vars

---

### 📋 Verification

Tested against goss v0.4.4+ on Ubuntu 26.04 LTS with sudo-rs default installation.
