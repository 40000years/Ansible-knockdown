$ErrorActionPreference = "Stop"

Write-Host "=================================================="
Write-Host " 🚀 Installing Radahn Dashboard System (Windows)..."
Write-Host "=================================================="

# Check dependencies
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: 'git' is not installed. Please install Git for Windows." -ForegroundColor Red
    exit 1
}

if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: 'docker' is not installed. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

$InstallDir = "$env:USERPROFILE\.radahn-system"

# Clone or Update
if (Test-Path $InstallDir) {
    Write-Host "🔄 Updating existing Radahn installation..." -ForegroundColor Cyan
    Set-Location $InstallDir
    git fetch origin Radahn
    git reset --hard origin/Radahn
} else {
    Write-Host "📥 Downloading Radahn System..." -ForegroundColor Cyan
    git clone -b Radahn https://github.com/40000years/Ansible-knockdown.git $InstallDir
}

# Setup PATH
$BinDir = "$InstallDir\terraform"
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($UserPath -notlike "*$BinDir*") {
    Write-Host "🔗 Adding Radahn to User PATH..." -ForegroundColor Cyan
    $NewPath = "$UserPath;$BinDir"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    Write-Host "✅ PATH updated successfully!" -ForegroundColor Green
    $NeedsRestart = $true
} else {
    $NeedsRestart = $false
}

Write-Host "=================================================="
Write-Host " ✅ Installation Complete!" -ForegroundColor Green
Write-Host "=================================================="
if ($NeedsRestart) {
    Write-Host " 🛠️  Please restart your Command Prompt or PowerShell window."
}
Write-Host ""
Write-Host " 🚀 Then, you can start the dashboard anytime by typing:"
Write-Host "     radahn start"
Write-Host "=================================================="
