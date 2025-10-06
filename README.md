# Neovim Automated Installation Script

A comprehensive installation script that sets up Neovim with a complete plugin ecosystem for modern development.

## Features

This script installs and configures:

- ✅ **Neovim** (latest stable release)
- ✅ **Syntax highlighting** (nvim-treesitter)
- ✅ **Autocomplete & snippets** (nvim-cmp)
- ✅ **LSP support** (nvim-lspconfig)
- ✅ **File explorer** (neo-tree)
- ✅ **Fuzzy finder** (telescope)
- ✅ **Git integration** (gitsigns)
- ✅ **Status line** (lualine)
- ✅ **Color scheme** (catppuccin)
- ✅ **File icons** (nvim-web-devicons)
- ✅ **Keymap helper** (which-key)
- ✅ **Package manager** (Mason)
- ✅ **Image display support** (image.nvim)
- ✅ **Zettelkasten note-taking** (Telekasten)
- ✅ **Markdown preview** (markdown-preview.nvim, glow.nvim)
- ✅ **Obsidian integration** (obsidian.nvim - graph view)
- ✅ **Faster fuzzy search** (telescope-fzf-native)
- ✅ **Kanban board** (super-kanban.nvim - project management)

## Prerequisites

- **Git** (required)
- **Curl** (required)
- **Sudo access** (for system package installation)

The script will automatically detect your package manager (apt, pacman, or dnf) and install:
- Node.js & npm
- Python 3 & pip

## Installation

1. Clone this repository or download the script:
```bash
git clone https://github.com/bindrap/neovim
cd neovim
```

2. Make the script executable:
```bash
chmod +x install_neovim.sh
```

3. Run the installation script:
```bash
./install_neovim.sh
```

4. Source your shell configuration:
```bash
# For bash users
source ~/.bashrc

# For zsh users
source ~/.zshrc
```

Or simply restart your terminal.

## What the Script Does

1. **Downloads & installs Neovim** to `/opt/nvim-linux-x86_64`
2. **Adds Neovim to PATH** in both `~/.bashrc` and `~/.zshrc` (if they exist)
3. **Copies configuration** to `~/.config/nvim/`
4. **Installs system dependencies** (Node.js, npm, Python)
5. **Bootstraps lazy.nvim** plugin manager
6. **Installs all plugins** automatically
7. **Installs language servers** (Pyright, Lua Language Server) via Mason

## Usage

### Starting Neovim

```bash
nvim
```

### 📖 Complete Controls Guide

**See [CONTROLS.md](CONTROLS.md) for a comprehensive guide to all keybindings and commands!**

### Quick Start Keybindings

- **Ctrl+N** - Toggle file explorer (Neo-tree)
- **Ctrl+Space** - Trigger autocomplete
- **Tab** - Navigate autocomplete menu / Jump to next snippet field
- **Enter** - Confirm autocomplete selection
- **Space** (then wait) - Show all available keybindings

### Zettelkasten Note-Taking (Telekasten)

All notes are stored in `~/Documents/Notes` and can be synced with Nextcloud/Obsidian.

**Keybindings** (Leader key is `Space`):

- **Space + zf** - Find notes (fuzzy search)
- **Space + zd** - Find daily notes
- **Space + zg** - Search text in notes (grep)
- **Space + zz** - Follow link under cursor
- **Space + zn** - Create new note
- **Space + zt** - Go to today's daily note
- **Space + zW** - Go to this week's weekly note
- **Space + zc** - Show calendar
- **Space + zb** - Show backlinks (what links to this note)
- **Space + zI** - Insert image link

**Creating Wiki Links:**
- Type `[[Note Name]]` to create a link
- Press `Space + zz` on a link to follow it (creates the note if it doesn't exist)

**Visualizing Graph:**
Since notes are plain Markdown in `~/Documents/Notes`:
1. Open the folder in Obsidian to see the graph view
2. Or use Logseq for graph visualization
3. Your notes remain portable and accessible anywhere!

### Kanban Project Management (Super-Kanban)

Manage your projects and tasks with an integrated kanban board stored in `~/.kanban/`.

**Keybindings:**
- **Space + kb** - Open kanban board

**Features:**
- Create multiple project boards
- Organize tasks across columns
- Navigate between boards with Telescope
- Keyboard-centric workflow
- Minimal and customizable interface

### Installing Additional Language Servers

1. Open Neovim
2. Run `:Mason`
3. Browse and install language servers with `i`

## Supported Languages (Pre-configured)

- **Python** (Pyright LSP)
- **Lua** (Lua Language Server)
- **JavaScript/TypeScript** (via Treesitter)
- **HTML/CSS** (via Treesitter)
- **JSON** (via Treesitter)

## Customization

Edit the configuration file at:
```
~/.config/nvim/init.lua
```

### Important Configuration Settings

**Obsidian.nvim UI Features:**
The configuration includes `conceallevel = 2` which enables Obsidian.nvim's UI features like hiding markdown syntax. If you want to see raw markdown syntax, you can:
1. Disable it temporarily: `:set conceallevel=0`
2. Or remove/modify this line in `init.lua`:
```lua
vim.opt.conceallevel = 2  -- Required for Obsidian.nvim UI features
```

### Adding More Languages to Treesitter

Find this section in `init.lua`:
```lua
ensure_installed = { "lua", "python", "javascript", "html", "css", "json" }
```

Add your languages to the list.

### Installing Additional LSP Servers

Add LSP configurations in the `nvim-lspconfig` section:
```lua
lspconfig.your_lsp_name.setup({})
```

## Troubleshooting

### nvim command not found

Try sourcing your shell config:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

Or restart your terminal.

### Plugins not loading

Run this inside Neovim:
```vim
:Lazy sync
```

### Language server not working

1. Check if it's installed: `:Mason`
2. Install manually: `:MasonInstall <server-name>`
3. Restart Neovim

## Uninstallation

To remove Neovim and its configuration:

```bash
# Remove Neovim binary
sudo rm -rf /opt/nvim-linux-x86_64

# Remove configuration
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim
rm -rf ~/.cache/nvim

# Remove PATH entries from shell configs
sed -i '/nvim-linux-x86_64/d' ~/.bashrc
sed -i '/nvim-linux-x86_64/d' ~/.zshrc
```

## System Requirements

- **OS**: Linux x86_64
- **Disk Space**: ~500MB (including all plugins and language servers)
- **RAM**: 512MB minimum (2GB+ recommended for LSP)

## Supported Package Managers

- apt (Debian/Ubuntu)
- pacman (Arch Linux/EndeavourOS/Manjaro)
- dnf (Fedora/RHEL)

## License

This configuration is provided as-is for personal and educational use.

## Contributing

Feel free to submit issues or pull requests to improve this installation script.

## Credits

- [Neovim](https://neovim.io/)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- All plugin authors listed in the features section

---

**Happy coding with Neovim! 🚀**
