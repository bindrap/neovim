#!/bin/bash

# Neovim Installation Script with Plugin Setup
# This script installs Neovim and sets up all configured plugins

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

# 1. Install Neovim
print_info "Installing Neovim..."

# Remove existing installation if present
if [ -d "/opt/nvim-linux-x86_64" ]; then
    print_warning "Removing existing Neovim installation..."
    sudo rm -rf /opt/nvim-linux-x86_64
fi

# Download and install Neovim
print_info "Downloading Neovim..."
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz

print_info "Extracting Neovim to /opt..."
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

# Clean up downloaded file
rm nvim-linux-x86_64.tar.gz

# 2. Add Neovim to PATH
print_info "Adding Neovim to PATH..."

# Add to bashrc if it exists
if [ -f ~/.bashrc ]; then
    if ! grep -q "/opt/nvim-linux-x86_64/bin" ~/.bashrc; then
        echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
        print_success "Added Neovim to PATH in ~/.bashrc"
    else
        print_info "Neovim already in PATH (~/.bashrc)"
    fi
fi

# Add to zshrc if it exists
if [ -f ~/.zshrc ]; then
    if ! grep -q "/opt/nvim-linux-x86_64/bin" ~/.zshrc; then
        echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.zshrc
        print_success "Added Neovim to PATH in ~/.zshrc"
    else
        print_info "Neovim already in PATH (~/.zshrc)"
    fi
fi

# Also add to current session
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# 3. Set up Neovim configuration directory
print_info "Setting up Neovim configuration..."

# Create config directory
mkdir -p ~/.config/nvim/lua

# Copy configuration files
print_info "Copying configuration files..."
cp init.lua ~/.config/nvim/

# 4. Install prerequisites
print_info "Installing prerequisites..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is required but not installed. Please install git first."
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    print_error "Curl is required but not installed. Please install curl first."
    exit 1
fi

# 5. Install language servers and tools via system package manager (optional)
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

# 6. Start Neovim to trigger plugin installation
print_info "Starting Neovim to install plugins..."
print_warning "Neovim will start and install plugins automatically."
print_warning "This may take a few minutes. Please wait for the installation to complete."
print_warning "You can close Neovim with :q once the installation is finished."

# Launch Neovim with the configuration
nvim --headless "+Lazy! sync" +qa

print_success "Plugin installation completed!"

# 7. Install Mason tools
print_info "Installing Mason language servers and tools..."
print_info "Starting Neovim to install Mason packages..."

# Install common LSP servers and tools via Mason
nvim --headless -c "MasonInstall pyright lua-language-server" -c "qa"

print_success "Mason tools installation completed!"

# 8. Final steps
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

print_success "Happy coding with Neovim! 🚀"