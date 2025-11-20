#!/bin/bash

# Neovim Bulletproof Installation Script
# This script installs Neovim and sets up all configured plugins with comprehensive error handling
# Usage: curl -fsSL https://raw.githubusercontent.com/bindrap/neovim/main/install_neovim.sh | bash
# Or: ./install_neovim.sh

set -o errexit   # Exit on any error
set -o nounset   # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Global variables
SCRIPT_VERSION="2.0.0"
LOCK_FILE="/tmp/nvim_install.lock"
LOG_FILE="/tmp/nvim_install_$(date +%Y%m%d_%H%M%S).log"
ROLLBACK_NEEDED=false
BACKUP_DIR=""
TEMP_DIRS=()
NVIM_INSTALLED=false

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Print functions with logging
print_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}${msg}${NC}" | tee -a "$LOG_FILE"
}

print_success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}${msg}${NC}" | tee -a "$LOG_FILE"
}

print_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}" | tee -a "$LOG_FILE"
}

print_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}" | tee -a "$LOG_FILE"
}

print_step() {
    local msg="$1"
    echo -e "${CYAN}==>${NC} ${msg}" | tee -a "$LOG_FILE"
}

# Cleanup function for trap
cleanup() {
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        print_error "Installation failed with exit code: $exit_code"
        print_info "Log file available at: $LOG_FILE"

        if [ "$ROLLBACK_NEEDED" = true ]; then
            print_warning "Attempting to rollback changes..."
            rollback_installation
        fi
    fi

    # Clean up temp directories
    for temp_dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$temp_dir" ]; then
            rm -rf "$temp_dir" 2>/dev/null || true
        fi
    done

    # Remove lock file
    rm -f "$LOCK_FILE" 2>/dev/null || true

    if [ "$exit_code" -eq 0 ]; then
        print_success "Cleanup completed successfully"
    fi
}

# Rollback function
rollback_installation() {
    print_warning "Rolling back installation..."

    # Restore backup if exists
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        print_info "Restoring previous configuration from: $BACKUP_DIR"
        rm -rf ~/.config/nvim 2>/dev/null || true
        mv "$BACKUP_DIR" ~/.config/nvim 2>/dev/null || true
        print_success "Previous configuration restored"
    fi

    # Note: We don't remove Neovim binary during rollback as it might be useful
    print_info "Neovim binary left installed at /opt (can be removed manually if needed)"
}

# Signal handlers
signal_handler() {
    local signal=$1
    print_error "Received signal: $signal"
    print_warning "Aborting installation..."
    cleanup
    exit 130
}

# Setup signal handlers
trap cleanup EXIT
trap 'signal_handler SIGINT' INT
trap 'signal_handler SIGTERM' TERM

# Check if another instance is running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            print_error "Another instance of this script is already running (PID: $pid)"
            print_info "If this is incorrect, remove the lock file: $LOCK_FILE"
            exit 1
        else
            print_warning "Stale lock file found, removing..."
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for safety reasons"
        print_info "The script will ask for sudo password when needed"
        exit 1
    fi
}

# Verify sudo access
check_sudo() {
    print_info "Checking sudo access..."

    if ! sudo -v; then
        print_error "Sudo access required but not available"
        exit 1
    fi

    # Keep sudo alive in background
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

# Check disk space (requires at least 1GB)
check_disk_space() {
    print_info "Checking available disk space..."

    local required_mb=1024
    local available_mb=$(df -m "$HOME" | awk 'NR==2 {print $4}')

    if [ "$available_mb" -lt "$required_mb" ]; then
        print_error "Insufficient disk space. Required: ${required_mb}MB, Available: ${available_mb}MB"
        exit 1
    fi

    print_success "Sufficient disk space available: ${available_mb}MB"
}

# Check required commands
check_dependencies() {
    print_step "Checking prerequisites..."

    local missing_deps=()

    # Required dependencies
    local required_commands=("git" "curl" "tar" "mkdir" "cp" "rm" "sed" "grep" "awk")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install missing tools and try again"
        exit 1
    fi

    # Check for optional but recommended tools
    if ! command -v unzip &> /dev/null; then
        print_warning "unzip not found - font installation will be skipped"
        print_info "Install with: sudo apt install unzip (Debian/Ubuntu) or sudo pacman -S unzip (Arch)"
    fi

    if ! command -v fc-cache &> /dev/null; then
        print_warning "fc-cache not found - font cache won't be updated"
    fi

    print_success "All required dependencies are installed"
}

# Retry function for network operations
retry_command() {
    local max_attempts=5
    local timeout=2
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            print_info "Retry attempt $attempt of $max_attempts (waiting ${timeout}s)..."
            sleep $timeout
            timeout=$((timeout * 2))
        fi

        # Execute command
        if "$@"; then
            return 0
        else
            exit_code=$?
        fi

        attempt=$((attempt + 1))
    done

    print_error "Command failed after $max_attempts attempts"
    return $exit_code
}

# Download file with retry and verification
download_file() {
    local url=$1
    local output=$2
    local description=${3:-"file"}

    print_info "Downloading $description..."

    # Try with progress bar first, fallback to silent mode
    if ! retry_command curl -fL --progress-bar -o "$output" "$url" 2>/dev/null; then
        if ! retry_command curl -fsSL -o "$output" "$url"; then
            print_error "Failed to download $description from: $url"
            return 1
        fi
    fi

    # Verify file was downloaded and is not empty
    if [ ! -f "$output" ] || [ ! -s "$output" ]; then
        print_error "Downloaded file is missing or empty: $output"
        return 1
    fi

    print_success "Downloaded $description successfully"
    return 0
}

# Detect system architecture
detect_architecture() {
    print_step "Detecting system architecture..."

    local arch=$(uname -m)

    case "$arch" in
        x86_64)
            NVIM_TARBALL="nvim-linux-x86_64.tar.gz"
            NVIM_DIR="nvim-linux-x86_64"
            ;;
        aarch64|arm64)
            NVIM_TARBALL="nvim-linux-arm64.tar.gz"
            NVIM_DIR="nvim-linux-arm64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            print_info "Supported architectures: x86_64, aarch64, arm64"
            exit 1
            ;;
    esac

    print_success "Detected architecture: $arch"
    print_info "Using Neovim package: $NVIM_TARBALL"
}

# Install Neovim
install_neovim() {
    print_step "Installing Neovim..."

    local nvim_url="https://github.com/neovim/neovim/releases/latest/download/$NVIM_TARBALL"
    local temp_tarball="/tmp/$NVIM_TARBALL"

    # Remove existing installation if present
    if [ -d "/opt/$NVIM_DIR" ]; then
        print_warning "Removing existing Neovim installation..."
        if ! sudo rm -rf "/opt/$NVIM_DIR"; then
            print_error "Failed to remove existing installation"
            return 1
        fi
    fi

    # Download Neovim
    if ! download_file "$nvim_url" "$temp_tarball" "Neovim ($NVIM_TARBALL)"; then
        return 1
    fi

    # Extract to /opt
    print_info "Extracting Neovim to /opt..."
    if ! sudo tar -C /opt -xzf "$temp_tarball"; then
        print_error "Failed to extract Neovim"
        rm -f "$temp_tarball"
        return 1
    fi

    # Clean up tarball
    rm -f "$temp_tarball"

    # Verify installation
    local nvim_binary="/opt/$NVIM_DIR/bin/nvim"
    if [ ! -x "$nvim_binary" ]; then
        print_error "Neovim binary not found or not executable: $nvim_binary"
        return 1
    fi

    # Test Neovim
    if ! "$nvim_binary" --version &> /dev/null; then
        print_error "Neovim binary exists but fails to run"
        return 1
    fi

    NVIM_INSTALLED=true
    print_success "Neovim installed successfully to /opt/$NVIM_DIR"

    # Show version
    local nvim_version=$("$nvim_binary" --version | head -n1)
    print_info "Installed version: $nvim_version"
}

# Add Neovim to PATH safely
add_to_path() {
    print_step "Adding Neovim to PATH..."

    local nvim_path="/opt/$NVIM_DIR/bin"
    local shells=()

    # Detect available shells
    [ -f ~/.bashrc ] && shells+=("bash:$HOME/.bashrc")
    [ -f ~/.zshrc ] && shells+=("zsh:$HOME/.zshrc")
    [ -f ~/.profile ] && shells+=("profile:$HOME/.profile")

    if [ ${#shells[@]} -eq 0 ]; then
        print_warning "No shell configuration files found (.bashrc, .zshrc, .profile)"
        print_info "You'll need to manually add to PATH: export PATH=\"\$PATH:$nvim_path\""
        return 0
    fi

    for shell_info in "${shells[@]}"; do
        local shell_name="${shell_info%%:*}"
        local shell_file="${shell_info#*:}"

        # Backup shell config
        if ! cp "$shell_file" "${shell_file}.backup.$(date +%Y%m%d_%H%M%S)"; then
            print_warning "Failed to backup $shell_file"
        fi

        # Remove old nvim paths (more robust pattern)
        if command -v sed &> /dev/null; then
            sed -i.tmp '/nvim-linux.*\/bin/d' "$shell_file" 2>/dev/null || true
            rm -f "${shell_file}.tmp" 2>/dev/null || true
        fi

        # Add to PATH if not already present
        if ! grep -q "$nvim_path" "$shell_file" 2>/dev/null; then
            echo "" >> "$shell_file"
            echo "# Added by Neovim installer ($(date +%Y-%m-%d))" >> "$shell_file"
            echo "export PATH=\"\$PATH:$nvim_path\"" >> "$shell_file"
            print_success "Added Neovim to PATH in $shell_file"
        else
            print_info "Neovim already in PATH ($shell_file)"
        fi
    done

    # Add to current session
    export PATH="$PATH:$nvim_path"

    # Verify nvim is now accessible
    if command -v nvim &> /dev/null; then
        print_success "nvim command is now available in current session"
    else
        print_warning "nvim not yet available in current session (will work after restart)"
    fi
}

# Setup configuration files
setup_configuration() {
    print_step "Setting up Neovim configuration..."

    ROLLBACK_NEEDED=true

    # Determine script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_url="https://github.com/bindrap/neovim.git"
    local config_source=""

    # Check if running from repo directory
    if [ -f "$script_dir/init.lua" ] && [ -d "$script_dir/lua" ]; then
        config_source="$script_dir"
        print_info "Using local configuration from: $config_source"
    else
        # Clone repository
        print_info "Configuration files not found locally, cloning repository..."
        local temp_repo=$(mktemp -d)
        TEMP_DIRS+=("$temp_repo")

        if ! retry_command git clone --depth 1 "$repo_url" "$temp_repo"; then
            print_error "Failed to clone repository from: $repo_url"
            return 1
        fi

        config_source="$temp_repo"
        print_success "Repository cloned to: $config_source"
    fi

    # Verify config files exist
    if [ ! -f "$config_source/init.lua" ]; then
        print_error "init.lua not found in: $config_source"
        return 1
    fi

    # Backup existing config
    if [ -d ~/.config/nvim ]; then
        BACKUP_DIR=~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
        print_warning "Existing Neovim config found, creating backup..."

        if ! mv ~/.config/nvim "$BACKUP_DIR"; then
            print_error "Failed to backup existing configuration"
            return 1
        fi

        print_success "Backup created at: $BACKUP_DIR"
    fi

    # Create config directory
    if ! mkdir -p ~/.config/nvim; then
        print_error "Failed to create config directory"
        return 1
    fi

    # Copy configuration files
    print_info "Copying configuration files..."

    # Copy init.lua
    if ! cp "$config_source/init.lua" ~/.config/nvim/; then
        print_error "Failed to copy init.lua"
        return 1
    fi
    print_success "✓ Copied init.lua"

    # Copy lua directory
    if [ -d "$config_source/lua" ]; then
        if ! cp -r "$config_source/lua" ~/.config/nvim/; then
            print_error "Failed to copy lua/ directory"
            return 1
        fi
        print_success "✓ Copied lua/ directory"
    else
        print_warning "lua/ directory not found, creating empty directory"
        mkdir -p ~/.config/nvim/lua
    fi

    # Copy lazy-lock.json (optional)
    if [ -f "$config_source/lazy-lock.json" ]; then
        if ! cp "$config_source/lazy-lock.json" ~/.config/nvim/; then
            print_warning "Failed to copy lazy-lock.json (non-critical)"
        else
            print_success "✓ Copied lazy-lock.json (plugin version lock)"
        fi
    else
        print_warning "lazy-lock.json not found, plugins will use latest versions"
    fi

    # Copy CONTROLS.md (optional)
    if [ -f "$config_source/CONTROLS.md" ]; then
        if ! cp "$config_source/CONTROLS.md" ~/.config/nvim/; then
            print_warning "Failed to copy CONTROLS.md (non-critical)"
        else
            print_success "✓ Copied CONTROLS.md (help guide: Space + h h)"
        fi
    else
        print_warning "CONTROLS.md not found, help guide will not be available"
    fi

    # Verify configuration was copied
    if [ ! -f ~/.config/nvim/init.lua ]; then
        print_error "Configuration verification failed: init.lua missing"
        return 1
    fi

    print_success "Configuration setup completed successfully"
}

# Install Nerd Font
install_nerd_font() {
    print_step "Installing JetBrains Mono Nerd Font..."

    # Determine font directory
    local font_dir=""
    case "$OSTYPE" in
        linux-gnu*)
            font_dir="$HOME/.local/share/fonts"
            ;;
        darwin*)
            font_dir="$HOME/Library/Fonts"
            ;;
        *)
            print_warning "Unknown OS type: $OSTYPE, skipping font installation"
            return 0
            ;;
    esac

    # Create font directory
    if ! mkdir -p "$font_dir"; then
        print_warning "Failed to create font directory, skipping font installation"
        return 0
    fi

    # Check if already installed
    if ls "$font_dir"/JetBrainsMono*Nerd*.ttf &>/dev/null; then
        print_info "JetBrains Mono Nerd Font already installed"
        return 0
    fi

    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        print_warning "unzip not found, skipping font installation"
        print_info "Install unzip and re-run: sudo apt install unzip (Debian/Ubuntu)"
        return 0
    fi

    # Download and install font
    local font_name="JetBrainsMono"
    local font_version="3.2.1"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${font_version}/${font_name}.zip"
    local font_temp_dir=$(mktemp -d)
    TEMP_DIRS+=("$font_temp_dir")

    if ! download_file "$font_url" "$font_temp_dir/${font_name}.zip" "JetBrainsMono Nerd Font"; then
        print_warning "Failed to download font (non-critical)"
        return 0
    fi

    # Extract fonts
    print_info "Extracting font files..."
    if ! (cd "$font_temp_dir" && unzip -q "${font_name}.zip" 2>/dev/null); then
        print_warning "Failed to extract font files (non-critical)"
        return 0
    fi

    # Copy TTF files (skip variable and Windows fonts)
    local font_count=0
    while IFS= read -r -d '' font_file; do
        if ! echo "$font_file" | grep -qi "windows"; then
            if cp "$font_file" "$font_dir/"; then
                font_count=$((font_count + 1))
            fi
        fi
    done < <(find "$font_temp_dir" -name "*.ttf" -print0 2>/dev/null)

    if [ $font_count -eq 0 ]; then
        print_warning "No font files were copied"
        return 0
    fi

    # Update font cache (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v fc-cache &> /dev/null; then
        print_info "Updating font cache..."
        if fc-cache -f "$font_dir" 2>/dev/null; then
            print_success "Font cache updated"
        fi
    fi

    print_success "JetBrains Mono Nerd Font installed ($font_count files)"
    print_info "Remember to set your terminal font to 'JetBrainsMono Nerd Font'"
}

# Install system dependencies
install_system_dependencies() {
    print_step "Installing system dependencies..."

    local pkg_manager=""
    local install_cmd=""

    # Detect package manager
    if command -v apt &> /dev/null; then
        pkg_manager="apt"
        print_info "Detected package manager: apt (Debian/Ubuntu)"

        print_info "Updating package lists..."
        if ! sudo apt update; then
            print_warning "Failed to update package lists (continuing anyway)"
        fi

        print_info "Installing nodejs, npm, python3, python3-pip..."
        if ! sudo apt install -y nodejs npm python3 python3-pip 2>&1 | tee -a "$LOG_FILE"; then
            print_warning "Some packages may have failed to install"
        fi

    elif command -v pacman &> /dev/null; then
        pkg_manager="pacman"
        print_info "Detected package manager: pacman (Arch Linux)"

        print_info "Syncing package databases..."
        if ! sudo pacman -Sy --noconfirm 2>&1 | tee -a "$LOG_FILE"; then
            print_warning "Package database sync had issues (continuing anyway)"
        fi

        print_info "Installing nodejs, npm, python, python-pip..."
        if ! sudo pacman -S --needed --noconfirm nodejs npm python python-pip 2>&1 | tee -a "$LOG_FILE"; then
            print_warning "Some packages may have failed to install due to mirror issues"
        fi

    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        print_info "Detected package manager: dnf (Fedora/RHEL)"

        print_info "Installing nodejs, npm, python3, python3-pip..."
        if ! sudo dnf install -y nodejs npm python3 python3-pip 2>&1 | tee -a "$LOG_FILE"; then
            print_warning "Some packages may have failed to install"
        fi

    elif command -v brew &> /dev/null; then
        pkg_manager="brew"
        print_info "Detected package manager: brew (macOS/Linux)"

        print_info "Installing node, python..."
        if ! brew install node python 2>&1 | tee -a "$LOG_FILE"; then
            print_warning "Some packages may have failed to install"
        fi

    else
        print_warning "No supported package manager detected (apt, pacman, dnf, brew)"
        print_info "Please manually install: nodejs, npm, python3, python3-pip"
        return 0
    fi

    # Verify installations
    local all_installed=true

    if ! command -v node &> /dev/null; then
        print_warning "Node.js not available after installation"
        all_installed=false
    else
        print_success "Node.js: $(node --version 2>/dev/null || echo 'installed')"
    fi

    if ! command -v npm &> /dev/null; then
        print_warning "npm not available after installation"
        all_installed=false
    else
        print_success "npm: $(npm --version 2>/dev/null || echo 'installed')"
    fi

    if ! command -v python3 &> /dev/null; then
        print_warning "Python 3 not available after installation"
        all_installed=false
    else
        print_success "Python 3: $(python3 --version 2>/dev/null || echo 'installed')"
    fi

    if [ "$all_installed" = true ]; then
        print_success "All system dependencies installed successfully"
    else
        print_warning "Some dependencies may be missing - LSP features might not work fully"
        print_info "You can install language servers manually later using :Mason in Neovim"
    fi
}

# Install Neovim plugins
install_plugins() {
    print_step "Installing Neovim plugins..."

    local nvim_cmd="/opt/$NVIM_DIR/bin/nvim"

    if [ ! -x "$nvim_cmd" ]; then
        print_error "Neovim binary not found: $nvim_cmd"
        return 1
    fi

    print_warning "This may take a few minutes depending on your internet connection..."
    print_info "Installing plugins with lazy.nvim..."

    # Run plugin installation
    if ! "$nvim_cmd" --headless "+Lazy! sync" +qa 2>&1 | tee -a "$LOG_FILE"; then
        print_warning "Plugin installation completed with some warnings (check log for details)"
    else
        print_success "Plugins installed successfully"
    fi

    # Verify plugin directory exists
    if [ -d ~/.local/share/nvim/lazy ]; then
        local plugin_count=$(find ~/.local/share/nvim/lazy -mindepth 1 -maxdepth 1 -type d | wc -l)
        print_success "Plugin directory created with $plugin_count plugins"
    else
        print_warning "Plugin directory not found - plugins may not have installed correctly"
    fi
}

# Install Mason tools
install_mason_tools() {
    print_step "Installing Mason language servers..."

    local nvim_cmd="/opt/$NVIM_DIR/bin/nvim"

    print_info "Installing pyright and lua-language-server..."
    print_warning "This step may fail if Node.js/npm is not properly configured (non-critical)"

    # Disable strict error checking for this optional step
    set +o errexit

    if "$nvim_cmd" --headless -c "MasonInstall pyright lua-language-server" -c "qa" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Mason tools installed successfully"
    else
        print_warning "Mason tools installation had issues (this is normal if Node.js/npm needs configuration)"
        print_info "You can install language servers manually later using :Mason in Neovim"
    fi

    # Re-enable strict error checking
    set -o errexit
}

# Print final instructions
print_final_instructions() {
    local nvim_version=$(/opt/$NVIM_DIR/bin/nvim --version | head -n1)

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║         ✨ Neovim Installation Completed Successfully! ✨        ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    print_success "$nvim_version installed with full plugin ecosystem"

    echo ""
    print_info "Installed Features:"
    echo "  ✅ Syntax highlighting (nvim-treesitter)"
    echo "  ✅ Autocomplete & snippets (nvim-cmp)"
    echo "  ✅ LSP support (nvim-lspconfig)"
    echo "  ✅ File explorer (neo-tree)"
    echo "  ✅ Fuzzy finder (telescope)"
    echo "  ✅ Git integration (gitsigns)"
    echo "  ✅ Status line (lualine)"
    echo "  ✅ Color scheme (catppuccin)"
    echo "  ✅ File icons (nvim-web-devicons)"
    echo "  ✅ Keymap helper (which-key)"
    echo "  ✅ Package manager (Mason)"
    echo "  ✅ Note-taking (Telekasten, Obsidian)"
    echo "  ✅ Markdown preview (glow.nvim)"
    echo "  ✅ Kanban board (super-kanban)"

    echo ""
    print_step "Quick Start Guide:"
    echo ""
    echo "  1️⃣  Reload your shell:"

    if [ -f ~/.zshrc ]; then
        echo "     $ source ~/.zshrc"
    elif [ -f ~/.bashrc ]; then
        echo "     $ source ~/.bashrc"
    fi

    echo ""
    echo "     Or simply restart your terminal"
    echo ""
    echo "  2️⃣  Set terminal font to 'JetBrainsMono Nerd Font' (REQUIRED for icons):"
    echo "     • GNOME Terminal: Edit → Preferences → Text → Custom font"
    echo "     • Alacritty: font.normal.family = 'JetBrainsMono Nerd Font'"
    echo "     • Kitty: font_family JetBrainsMono Nerd Font"
    echo "     • Windows Terminal: \"fontFace\": \"JetBrainsMono Nerd Font\""
    echo ""
    echo "  3️⃣  Launch Neovim:"
    echo "     $ nvim"
    echo ""
    echo "  4️⃣  Quick Commands:"
    echo "     • Space + h h     → View complete controls guide"
    echo "     • Ctrl + N        → Toggle file explorer"
    echo "     • Space + f       → Fuzzy finder"
    echo "     • :Mason          → Install language servers"
    echo "     • :Lazy           → Manage plugins"
    echo "     • :checkhealth    → Verify installation"
    echo ""

    print_step "Troubleshooting:"
    echo ""
    echo "  • Plugin errors:     nvim and run :Lazy sync"
    echo "  • LSP not working:   nvim and run :Mason to install servers"
    echo "  • Health check:      nvim and run :checkhealth"
    echo "  • View log file:     cat $LOG_FILE"

    if [ -n "$BACKUP_DIR" ]; then
        echo "  • Restore backup:    mv $BACKUP_DIR ~/.config/nvim"
    fi

    echo ""
    print_step "Additional Resources:"
    echo ""
    echo "  • GitHub: https://github.com/bindrap/neovim"
    echo "  • Neovim Docs: :help"
    echo "  • Controls Guide: Space + h h (in Neovim)"
    echo ""

    print_success "Happy coding with Neovim! 🚀"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║       🚀 Neovim Bulletproof Installation Script v${SCRIPT_VERSION} 🚀      ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    print_info "Installation log: $LOG_FILE"
    print_info "Starting installation at: $(date)"
    echo ""

    # Pre-flight checks
    check_lock
    check_not_root
    check_dependencies
    check_sudo
    check_disk_space

    # Detect system
    detect_architecture

    # Install components
    install_neovim || {
        print_error "Neovim installation failed"
        exit 1
    }

    add_to_path || {
        print_error "Failed to add Neovim to PATH"
        exit 1
    }

    setup_configuration || {
        print_error "Configuration setup failed"
        exit 1
    }

    # Optional components (don't fail on errors)
    install_nerd_font
    install_system_dependencies
    install_plugins || {
        print_warning "Plugin installation had issues, but continuing..."
    }
    install_mason_tools

    # Success - disable rollback
    ROLLBACK_NEEDED=false

    # Show final instructions
    print_final_instructions

    print_info "Installation completed at: $(date)"
    print_info "Total time: $SECONDS seconds"
}

# Run main function
main "$@"
