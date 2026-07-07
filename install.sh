#!/bin/bash
set -e

echo "=================================================="
echo " 🚀 Installing Radahn Dashboard System..."
echo "=================================================="

# Check for Git
if ! command -v git &> /dev/null; then
    echo "❌ Error: 'git' is not installed. Please install git first."
    exit 1
fi

# Check for Docker and attempt to install if missing
if ! command -v docker &> /dev/null; then
    echo "📦 Docker not found. Attempting to install Docker automatically..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y docker.io
        sudo systemctl enable --now docker || true
    elif command -v yum &> /dev/null; then
        sudo yum install -y docker
        sudo systemctl enable --now docker || true
    else
        echo "❌ Error: Cannot automatically install Docker on this OS. Please install Docker manually."
        exit 1
    fi
fi

INSTALL_DIR="$HOME/.radahn-system"

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Updating existing Radahn installation..."
    cd "$INSTALL_DIR"
    git fetch origin Radahn
    git reset --hard origin/Radahn
else
    echo "📥 Downloading Radahn System..."
    git clone -b Radahn https://github.com/40000years/Ansible-knockdown.git "$INSTALL_DIR"
fi

# Setup Alias
ALIAS_CMD="alias radahn=\"$INSTALL_DIR/terraform/radahn.sh\""
PROFILE_UPDATED=false

# Update .zshrc if exists or if on macOS
if [ -f "$HOME/.zshrc" ] || [ "$(uname)" == "Darwin" ]; then
    if ! grep -q "alias radahn=" "$HOME/.zshrc" 2>/dev/null; then
        echo -e "\n# Radahn Dashboard\n$ALIAS_CMD" >> "$HOME/.zshrc"
    fi
    PROFILE_UPDATED=true
fi

# Update .bashrc if exists or if on Linux
if [ -f "$HOME/.bashrc" ] || [ "$(uname)" == "Linux" ]; then
    if ! grep -q "alias radahn=" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "\n# Radahn Dashboard\n$ALIAS_CMD" >> "$HOME/.bashrc"
    fi
    PROFILE_UPDATED=true
fi

# Make script executable
chmod +x "$INSTALL_DIR/terraform/radahn.sh"

echo "=================================================="
echo " ✅ Installation Complete!"
echo "=================================================="
echo " 🛠️  Please restart your terminal OR run:"
if [ "$(uname)" == "Darwin" ]; then
    echo "     source ~/.zshrc"
else
    echo "     source ~/.bashrc"
fi
echo ""
echo " 🚀 Then, you can start the dashboard anytime by typing:"
echo "     radahn start"
echo "=================================================="
