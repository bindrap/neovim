#!/bin/bash

# Neovim Installation Script with Plugin Setup
# This script installs Neovim and sets up all configured plugins
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install_neovim.sh | bash
# Or: ./install_neovim.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for safety reasons"
   exit 1
fi

print_info "Starting Neovim installation and configuration..."

# Determine script directory and config location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/bindrap/neovim.git"  # Change this to your repo URL

# 1. Check for required tools
print_info "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    print_error "Git is required but not installed. Please install git first."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    print_error "Curl is required but not installed. Please install curl first."
    exit 1
fi

# 2. Determine architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    NVIM_TARBALL="nvim-linux-x86_64.tar.gz"
    NVIM_DIR="nvim-linux-x86_64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    NVIM_TARBALL="nvim-linux-arm64.tar.gz"
    NVIM_DIR="nvim-linux-arm64"
else
    print_error "Unsupported architecture: $ARCH"
    exit 1
fi

print_info "Detected architecture: $ARCH"

# 3. Install Neovim
print_info "Installing Neovim..."

# Remove existing installation if present
if [ -d "/opt/$NVIM_DIR" ]; then
    print_warning "Removing existing Neovim installation..."
    sudo rm -rf /opt/$NVIM_DIR
fi

# Download and install Neovim
print_info "Downloading Neovim ($NVIM_TARBALL)..."
curl -LO "https://github.com/neovim/neovim/releases/latest/download/$NVIM_TARBALL"

print_info "Extracting Neovim to /opt..."
sudo tar -C /opt -xzf "$NVIM_TARBALL"

# Clean up downloaded file
rm "$NVIM_TARBALL"

# 4. Add Neovim to PATH
print_info "Adding Neovim to PATH..."

NVIM_PATH="/opt/$NVIM_DIR/bin"

# Add to bashrc if it exists
if [ -f ~/.bashrc ]; then
    # Remove old paths first
    sed -i '/nvim-linux.*\/bin/d' ~/.bashrc
    if ! grep -q "$NVIM_PATH" ~/.bashrc; then
        echo "export PATH=\"\$PATH:$NVIM_PATH\"" >> ~/.bashrc
        print_success "Added Neovim to PATH in ~/.bashrc"
    else
        print_info "Neovim already in PATH (~/.bashrc)"
    fi
fi

# Add to zshrc if it exists
if [ -f ~/.zshrc ]; then
    # Remove old paths first
    sed -i '/nvim-linux.*\/bin/d' ~/.zshrc
    if ! grep -q "$NVIM_PATH" ~/.zshrc; then
        echo "export PATH=\"\$PATH:$NVIM_PATH\"" >> ~/.zshrc
        print_success "Added Neovim to PATH in ~/.zshrc"
    else
        print_info "Neovim already in PATH (~/.zshrc)"
    fi
fi

# Also add to current session
export PATH="$PATH:$NVIM_PATH"

# 5. Set up Neovim configuration directory
print_info "Setting up Neovim configuration..."

# Determine config source location
CONFIG_SOURCE=""

# Check if we're running from the repo directory
if [ -f "$SCRIPT_DIR/init.lua" ] && [ -d "$SCRIPT_DIR/lua" ]; then
    CONFIG_SOURCE="$SCRIPT_DIR"
    print_info "Using configuration from: $CONFIG_SOURCE"
else
    # Clone the repo to a temporary location
    print_info "Configuration files not found locally. Cloning repository..."
    TEMP_DIR=$(mktemp -d)
    git clone "$REPO_URL" "$TEMP_DIR"
    CONFIG_SOURCE="$TEMP_DIR"
    print_success "Repository cloned to: $CONFIG_SOURCE"
fi

# Backup existing config if present
BACKUP_DIR=""
if [ -d ~/.config/nvim ]; then
    BACKUP_DIR=~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
    print_warning "Existing Neovim config found. Creating backup at: $BACKUP_DIR"
    mv ~/.config/nvim "$BACKUP_DIR"
fi

# Create config directory
mkdir -p ~/.config/nvim

# Copy configuration files
print_info "Copying configuration files..."

if [ -f "$CONFIG_SOURCE/init.lua" ]; then
    cp "$CONFIG_SOURCE/init.lua" ~/.config/nvim/
    print_success "Copied init.lua"
else
    print_error "init.lua not found in $CONFIG_SOURCE"
    exit 1
fi

if [ -d "$CONFIG_SOURCE/lua" ]; then
    cp -r "$CONFIG_SOURCE/lua" ~/.config/nvim/
    print_success "Copied lua/ directory"
else
    print_warning "lua/ directory not found, creating empty directory"
    mkdir -p ~/.config/nvim/lua
fi

if [ -f "$CONFIG_SOURCE/lazy-lock.json" ]; then
    cp "$CONFIG_SOURCE/lazy-lock.json" ~/.config/nvim/
    print_success "Copied lazy-lock.json (ensures consistent plugin versions)"
else
    print_warning "lazy-lock.json not found, plugins will use latest versions"
fi

# Clean up temp directory if we cloned
if [ "$CONFIG_SOURCE" != "$SCRIPT_DIR" ]; then
    rm -rf "$CONFIG_SOURCE"
    print_info "Cleaned up temporary files"
fi

# 6. Install language servers and tools via system package manager (optional)
print_info "Installing language servers and development tools..."

# Detect package manager and install tools
if command -v apt &> /dev/null; then
    print_info "Detected apt package manager"
    sudo apt update
    sudo apt install -y nodejs npm python3 python3-pip
elif command -v pacman &> /dev/null; then
    print_info "Detected pacman package manager"
    print_info "Updating package databases and mirrors..."
    sudo pacman -Sy --noconfirm
    print_info "Installing packages (will continue on mirror errors)..."
    sudo pacman -S --needed --noconfirm nodejs npm python python-pip || print_warning "Some packages may have failed to install due to mirror issues"
elif command -v dnf &> /dev/null; then
    print_info "Detected dnf package manager"
    sudo dnf install -y nodejs npm python3 python3-pip
else
    print_warning "Package manager not detected. Please install nodejs, npm, and python3 manually."
fi

# Install Python language server (via Mason instead of system pip)
# Skip system-wide Python package installation on Arch due to PEP 668
# Mason will handle LSP installation inside Neovim
print_info "Python language servers will be installed via Mason in Neovim"

# 7. Start Neovim to trigger plugin installation
print_info "Starting Neovim to install plugins..."
print_warning "Neovim will start and install plugins automatically."
print_warning "This may take a few minutes. Please wait for the installation to complete."
print_warning "You can close Neovim with :q once the installation is finished."

# Launch Neovim with the configuration
nvim --headless "+Lazy! sync" +qa

print_success "Plugin installation completed!"

# 8. Install Mason tools
print_info "Installing Mason language servers and tools..."
print_info "Starting Neovim to install Mason packages..."

# Install common LSP servers and tools via Mason
nvim --headless -c "MasonInstall pyright lua-language-server" -c "qa"

print_success "Mason tools installation completed!"

# 9. Final steps
print_info "Installation completed successfully!"
print_success "Neovim is now installed with the following features:"
echo "  ✅ Syntax highlighting (nvim-treesitter)"
echo "  ✅ Autocomplete and snippets (nvim-cmp)"
echo "  ✅ LSP support (nvim-lspconfig)"
echo "  ✅ File explorer (neo-tree)"
echo "  ✅ Fuzzy finder (telescope)"
echo "  ✅ Git integration (gitsigns)"
echo "  ✅ Status line (lualine)"
echo "  ✅ Color scheme (catppuccin)"
echo "  ✅ File icons (nvim-web-devicons)"
echo "  ✅ Keymap helper (which-key)"
echo "  ✅ Package manager (Mason)"

print_info "To start using Neovim:"
echo "  1. Restart your terminal or run:"
if [ -f ~/.zshrc ]; then
    echo "     source ~/.zshrc"
elif [ -f ~/.bashrc ]; then
    echo "     source ~/.bashrc"
fi
echo "  2. Launch Neovim with: nvim"
echo "  3. Open file explorer with: Ctrl+N"
echo "  4. Open a directory with: nvim ~/your-directory"

print_warning "Note: Some plugins may require additional setup or language servers."
print_info "You can install additional language servers using :Mason in Neovim."

if [ -n "$BACKUP_DIR" ]; then
    echo ""
    print_info "Your previous config was backed up to: $BACKUP_DIR"
fi

print_success "Happy coding with Neovim! 🚀"