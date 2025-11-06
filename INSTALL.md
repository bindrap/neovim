# Neovim Installation Script

This script installs Neovim and sets up your custom configuration on any Linux or WSL machine with a single command.

## Quick Install

### Method 1: Run from this repository

```bash
# Clone the repository
git clone https://github.com/bindrap/neovim.git
cd neovim

# Run the installation script
./install_neovim.sh
```

### Method 2: One-line remote install

```bash
# Download and run directly (make sure to update the URL in the script first)
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install_neovim.sh | bash
```

## What the script does

1. **Detects your system architecture** (x86_64 or ARM64)
2. **Downloads and installs** the latest Neovim release
3. **Adds Neovim to your PATH** (both bash and zsh)
4. **Backs up** your existing Neovim config (if any)
5. **Copies your custom config** files:
   - `init.lua`
   - `lua/` directory with all your custom modules
   - `lazy-lock.json` (ensures consistent plugin versions)
6. **Installs system dependencies** (nodejs, npm, python3)
7. **Automatically installs all plugins** via Lazy.nvim
8. **Sets up language servers** via Mason

## Requirements

The script will check for these prerequisites:
- `git`
- `curl`
- `sudo` access (for installing Neovim and system packages)

## Supported Systems

- Ubuntu/Debian (apt)
- Arch Linux (pacman)
- Fedora/RHEL (dnf)
- WSL (Windows Subsystem for Linux)
- Other Linux distributions (with manual dependency installation)

## Supported Architectures

- x86_64 (Intel/AMD)
- ARM64/aarch64 (ARM processors)

## After Installation

1. Restart your terminal or source your shell config:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

2. Launch Neovim:
   ```bash
   nvim
   ```

3. Key commands to get started:
   - `Ctrl+N` - Open file explorer
   - `:Mason` - Manage language servers
   - `:Lazy` - Manage plugins
   - `:help` - Neovim help

## Troubleshooting

### Config backup
If something goes wrong, your previous config is backed up at:
```
~/.config/nvim.backup.YYYYMMDD_HHMMSS/
```

To restore it:
```bash
rm -rf ~/.config/nvim
mv ~/.config/nvim.backup.YYYYMMDD_HHMMSS ~/.config/nvim
```

### Plugin installation fails
If plugins fail to install, try manually running:
```bash
nvim --headless "+Lazy! sync" +qa
```

### Language servers not working
Install them manually via Mason:
```bash
nvim
:Mason
# Use 'i' to install servers
```

## Customization

Before running the script, you can customize:

1. **Repository URL** (line 44 in the script):
   ```bash
   REPO_URL="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
   ```

2. **Mason LSP servers** (line 228 in the script):
   ```bash
   nvim --headless -c "MasonInstall pyright lua-language-server typescript-language-server" -c "qa"
   ```

## Features Included

Your Neovim setup includes:
- ✅ Syntax highlighting (nvim-treesitter)
- ✅ Autocomplete and snippets (nvim-cmp)
- ✅ LSP support (nvim-lspconfig)
- ✅ File explorer (neo-tree)
- ✅ Fuzzy finder (telescope)
- ✅ Git integration (gitsigns)
- ✅ Status line (lualine)
- ✅ Color scheme (catppuccin)
- ✅ File icons (nvim-web-devicons)
- ✅ Keymap helper (which-key)
- ✅ Package manager (Mason)
