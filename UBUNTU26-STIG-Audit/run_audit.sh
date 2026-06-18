#! /bin/bash
# Script to run the UBUNTU26-STIG goss audit
# Adapted from ansible-lockdown UBUNTU24-STIG-Audit
# Updated for Ubuntu 26.04 LTS (Resolute Raccoon) with sudo-rs support
#
# Changelog:
# 2026-06-18  Initial release for Ubuntu 26.04 LTS
#             Added sudo-rs detection and handling
#             Updated benchmark variables for UBUNTU26
#             Improved OS version detection for Ubuntu 26
#             Added JUnit output format support
#             Added --max-concurrent flag support

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Goss benchmark variables (do not change unless a new release requires it)
# ─────────────────────────────────────────────────────────────────────────────
BENCHMARK=STIG
BENCHMARK_VER=1.0.0
BENCHMARK_OS=UBUNTU26

# ─────────────────────────────────────────────────────────────────────────────
# Goss host variables (can be overridden via environment)
# ─────────────────────────────────────────────────────────────────────────────
AUDIT_BIN="${AUDIT_BIN:-/usr/local/bin/goss}"
AUDIT_BIN_MIN_VER="0.4.4"
AUDIT_FILE="${AUDIT_FILE:-goss.yml}"
AUDIT_CONTENT_LOCATION="${AUDIT_CONTENT_LOCATION:-/opt}"

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
Help() {
  echo "Script to run the UBUNTU26-STIG goss audit"
  echo
  echo "Syntax: $0 [-f|-g|-m|-o|-v|-w|-h]"
  echo "Options:"
  echo "  -f <format>  Output format: json (default), documentation, rspecish, junit"
  echo "  -g <group>   Server group tag (default: ungrouped)"
  echo "  -m <number>  Maximum concurrent goss processes (default: 50)"
  echo "  -o <file>    Output file path for audit results"
  echo "  -v <path>    Path to a custom vars file (default: vars/STIG.yml)"
  echo "  -w           Set system_type to Workstation (default: Server)"
  echo "  -h           Show this help message"
  echo
  echo "Environment variables:"
  echo "  AUDIT_BIN               Path to the goss binary (default: /usr/local/bin/goss)"
  echo "  AUDIT_FILE              Main goss file (default: goss.yml)"
  echo "  AUDIT_CONTENT_LOCATION  Location of audit content (default: /opt)"
  echo
  echo "Examples:"
  echo "  sudo $0                              # Run all CAT I/II/III checks, JSON output"
  echo "  sudo $0 -f documentation -o /tmp/audit_report.txt"
  echo "  sudo $0 -f junit -o /tmp/audit_junit.xml"
  echo "  sudo $0 -v /etc/stig/custom_vars.yml"
}

# ─────────────────────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────────────────────
FORMAT=json
GROUP=ungrouped
MAX=50
OUTFILE=""
VARS_PATH=""
host_system_type=Server

# ─────────────────────────────────────────────────────────────────────────────
# Parse options
# ─────────────────────────────────────────────────────────────────────────────
while getopts "f:g:m:o:v:wh" option; do
  case "${option}" in
    f) FORMAT="${OPTARG}" ;;
    g) GROUP="${OPTARG}" ;;
    m) MAX="${OPTARG}" ;;
    o) OUTFILE="${OPTARG}" ;;
    v) VARS_PATH="${OPTARG}" ;;
    w) host_system_type=Workstation ;;
    h)
      Help
      exit 0
      ;;
    ?)
      echo "ERROR: Invalid option: -${OPTARG}" >&2
      Help
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────

# Check for root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root or with sudo." >&2
  exit 1
fi

# Check goss binary exists
if [ ! -f "${AUDIT_BIN}" ]; then
  echo "ERROR: goss binary not found at '${AUDIT_BIN}'." >&2
  echo "       Install goss: curl -fsSL https://goss.rocks/install | sh" >&2
  exit 1
fi

# Version comparison helper
version_gte() {
  # Returns 0 (true) if $1 >= $2
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Check goss minimum version
AUDIT_BIN_VER="$("${AUDIT_BIN}" --version 2>&1 | grep -oP '\d+\.\d+\.\d+')"
if ! version_gte "${AUDIT_BIN_VER}" "${AUDIT_BIN_MIN_VER}"; then
  echo "ERROR: goss version ${AUDIT_BIN_VER} is below the minimum required ${AUDIT_BIN_MIN_VER}." >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Detect Ubuntu 26 and sudo-rs
# ─────────────────────────────────────────────────────────────────────────────

# Detect OS
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_NAME="${NAME:-Unknown}"
  OS_VERSION="${VERSION_ID:-Unknown}"
  OS_CODENAME="${VERSION_CODENAME:-unknown}"
else
  OS_NAME="Unknown"
  OS_VERSION="Unknown"
  OS_CODENAME="unknown"
fi

echo "============================================================"
echo " UBUNTU26 STIG Audit"
echo " Benchmark : ${BENCHMARK_OS}-${BENCHMARK} v${BENCHMARK_VER}"
echo " Host      : $(hostname -f)"
echo " OS        : ${OS_NAME} ${OS_VERSION} (${OS_CODENAME})"
echo " Date/Time : $(date '+%Y-%m-%dT%H:%M:%S%z')"
echo " System    : ${host_system_type}"
echo " Group     : ${GROUP}"
echo "============================================================"

# Warn if not Ubuntu 26
if [[ "${OS_VERSION}" != "26.04" ]]; then
  echo "WARNING: This audit is designed for Ubuntu 26.04 LTS."
  echo "         Detected OS version: ${OS_VERSION}. Results may be inaccurate." >&2
fi

# Detect sudo-rs vs classic sudo
SUDO_RS=false
SUDO_IMPL="unknown"
if command -v sudo &>/dev/null; then
  SUDO_VER_OUTPUT="$(sudo --version 2>&1 || true)"
  if echo "${SUDO_VER_OUTPUT}" | grep -qi "sudo-rs"; then
    SUDO_RS=true
    SUDO_IMPL="sudo-rs ($(echo "${SUDO_VER_OUTPUT}" | grep -oP 'sudo-rs \K[\d.]+'  || echo 'version unknown'))"
  else
    SUDO_IMPL="classic sudo ($(echo "${SUDO_VER_OUTPUT}" | grep -oP 'Sudo version \K[\d.]+' || echo 'version unknown'))"
  fi
fi

echo " sudo impl : ${SUDO_IMPL}"
echo "============================================================"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Resolve vars file
# ─────────────────────────────────────────────────────────────────────────────
AUDIT_CONTENT_DIR="${AUDIT_CONTENT_LOCATION}/${BENCHMARK_OS}-${BENCHMARK}"

if [ -z "${VARS_PATH}" ]; then
  VARS_PATH="${AUDIT_CONTENT_DIR}/vars/${BENCHMARK}.yml"
fi

if [ ! -f "${VARS_PATH}" ]; then
  echo "ERROR: Vars file not found: '${VARS_PATH}'" >&2
  echo "       Use -v <path> to specify a custom vars file." >&2
  exit 1
fi

# Inject sudo_rs detection into vars dynamically
VARS_INJECT=""
if [ "${SUDO_RS}" = true ]; then
  VARS_INJECT="ubtu26stig_sudo_rs: true\nubtu26stig_classic_sudo: false"
else
  VARS_INJECT="ubtu26stig_sudo_rs: false\nubtu26stig_classic_sudo: true"
fi

# Write a temporary merged vars file
TMP_VARS="$(mktemp /tmp/goss_vars_XXXXXX.yml)"
trap 'rm -f "${TMP_VARS}"' EXIT
cat "${VARS_PATH}" > "${TMP_VARS}"
printf "\n# Auto-detected by run_audit.sh\n%b\n" "${VARS_INJECT}" >> "${TMP_VARS}"

# ─────────────────────────────────────────────────────────────────────────────
# Resolve output
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "${OUTFILE}" ]; then
  OUTFILE_FLAG="--output-file ${OUTFILE}"
else
  OUTFILE_FLAG=""
fi

# ─────────────────────────────────────────────────────────────────────────────
# Run goss
# ─────────────────────────────────────────────────────────────────────────────
GOSS_CMD=(
  "${AUDIT_BIN}"
  --gossfile "${AUDIT_CONTENT_DIR}/${AUDIT_FILE}"
  --vars "${TMP_VARS}"
  validate
  --format "${FORMAT}"
  --max-concurrent "${MAX}"
)

# Add output file if specified
if [ -n "${OUTFILE}" ]; then
  GOSS_CMD+=(--output-file "${OUTFILE}")
fi

echo "Running goss audit..."
echo "Command: ${GOSS_CMD[*]}"
echo

# Execute goss – capture exit code but don't fail the script on non-zero
set +e
"${GOSS_CMD[@]}"
GOSS_EXIT_CODE=$?
set -e

echo
echo "============================================================"
if [ "${GOSS_EXIT_CODE}" -eq 0 ]; then
  echo " AUDIT RESULT: PASS – All enabled controls passed."
else
  echo " AUDIT RESULT: FAIL – One or more controls did not pass."
  echo "               Exit code: ${GOSS_EXIT_CODE}"
fi
[ -n "${OUTFILE}" ] && echo " Output saved: ${OUTFILE}"
echo "============================================================"

exit "${GOSS_EXIT_CODE}"
