# Contributing to UBUNTU26-STIG-Audit

Thank you for your interest in contributing to the UBUNTU26-STIG-Audit project!

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request new STIG control coverage
- Include your Ubuntu version (`lsb_release -a`), goss version (`goss --version`), and the failing control ID
- Specify whether your system uses `sudo-rs` or classic `sudo`

### Adding or Updating Controls

1. **Fork** this repository
2. **Create a branch**: `git checkout -b feature/UBTU-26-XXXXXX`
3. **Add/edit** the appropriate YAML file in `cat_1/`, `cat_2/`, or `cat_3/`
4. **Test** your changes on an actual Ubuntu 26.04 LTS system:
   ```bash
   sudo ./run_audit.sh -f documentation
   ```
5. **Submit a Pull Request** with:
   - The STIG control ID in the PR title (e.g., `Add UBTU-26-100999 - New control description`)
   - A reference to the DISA STIG document version
   - Test results (pass/fail output)

### File Naming Convention

| Category | Location | File naming |
|----------|----------|-------------|
| CAT I    | `cat_1/` | `UBTU-26-XXXXXX.yml` |
| CAT II   | `cat_2/UBTU-26-NNxxxx/` | `UBTU-26-NNNxxx.yml` |
| CAT III  | `cat_3/` | `UBTU-26-cat3.yml` or `UBTU-26-XXXXXX.yml` |

### YAML Control Template

```yaml
# UBTU-26-XXXXXX
# CAT I / II / III
# Short description of what this control checks.

{{ if .Vars.ubtu26stig_XXXXXX }}
command:
  UBTU-26-XXXXXX_check_name:
    title: "UBTU-26-XXXXXX | Human-readable description"
    exec: "command to check"
    exit-status: 0
    stdout:
      - "/expected pattern/"
    timeout: 10000
    meta:
      stig_id: UBTU-26-XXXXXX
      severity: CAT_I   # or CAT_II, CAT_III
      title: "Short title"
{{ end }}
```

### sudo-rs Considerations

When writing controls that interact with `sudo`:
- Use `.Vars.ubtu26stig_sudo_rs` to conditionally check for sudo-rs vs classic sudo behaviour
- Remember that `sudo-rs` **always enforces** `env_reset` — do not check for its absence
- The `sudo-rs` binary still responds to standard `sudo --version` but output includes "sudo-rs"

## Code of Conduct

Be respectful and constructive. This is a community security project — all contributions are appreciated.

## Questions?

Join the [Discord Server](https://www.lockdownenterprise.com/discord) or open a GitHub Discussion.
