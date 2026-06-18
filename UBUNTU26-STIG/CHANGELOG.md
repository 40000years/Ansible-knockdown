# Changelog

## [1.0.0] - 2026-06-18

### Added
- Initial release for Ubuntu 26.04 LTS (Resolute Raccoon)
- Full integration with UBUNTU26-STIG-Audit using `run_audit: true`
- Auto-detection for `sudo-rs` (Rust sudo) vs classic `sudo`
- Pre-flight checks and dynamic package detection
- Complete CAT I, CAT II, and CAT III remediation tasks
- Automated fetching of audit reports to the Ansible control node

### Changed
- Adapted rules from UBUNTU24-STIG to match Ubuntu 26 specifics
- `sshd_config` template updated for modern ciphers and KexAlgorithms
- `audit.rules` customized for `sudo-rs` logging

### Fixed
- Fixed integration issues with older goss binaries by forcing v0.4.4+ download
