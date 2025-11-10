# Parteek's Config v2.0 - Controls Guide

Quick reference for all keybindings and commands in your custom Neovim setup.

> **Font Note:** This guide uses Unicode characters (⚡📋🚀 and box-drawing characters).
> If you see `?` symbols, install a font with Unicode support like:
> - **JetBrains Mono Nerd Font** (recommended)
> - **Hack Nerd Font**
> - **FiraCode Nerd Font**
>
> Test display: ⚡ 📋 🚀 ├── └── • →
> All characters above should display correctly.

---

## ⚡ Quick Reference - Custom Keybindings

**Leader key is `Space`**

```
Essential Commands:
Ctrl+n           - File explorer (Neo-tree)
Space + f        - Custom fuzzy finder menu
Space + ww       - Open wishlist
Space + jj       - Jiu Jitsu notes
Space + kb       - Kanban boards
:DailyToday      - Open today's daily note

Zettelkasten:
Space + zf       - Find notes
Space + zn       - New note
Space + zT       - Today's daily note
Space + zg       - Search in notes
Space + zz       - Follow link
Space + zb       - Show backlinks
Space + ng       - Note graph (Obsidian-like visualization)

Code Navigation:
gd               - Go to definition
K                - Hover documentation
gr               - Show references
Space + ca       - Code actions
```

---

## 📋 Table of Contents

- [Basic Neovim Navigation](#basic-neovim-navigation)
- [File Management](#file-management)
- [Editing](#editing)
- [LSP & Code Intelligence](#lsp--code-intelligence)
- [Fuzzy Finding (Telescope)](#fuzzy-finding-telescope)
- [Git Integration (Gitsigns)](#git-integration-gitsigns)
- [Zettelkasten (Telekasten)](#zettelkasten-telekasten)
- [Custom Features](#custom-features)
- [Autocomplete](#autocomplete)
- [Useful Commands](#useful-commands)

---

## ⚡ Quick Help

**View this guide anytime:**
```
Space + h h      - Show this CONTROLS.md guide in popup window
:Help            - Same as above (custom command)
```
Opens in a centered floating popup with markdown highlighting. Press `ESC`, `q`, or `:q` to close.

---

## Basic Neovim Navigation

### Modes
- **Normal mode**: `Esc` - Default mode for navigation
- **Insert mode**: `i` - Start typing at cursor
- **Visual mode**: `v` - Select text
- **Visual line mode**: `V` - Select entire lines
- **Command mode**: `:` - Execute commands

### Movement
```
h j k l          - Left, Down, Up, Right
w / b            - Next/previous word
0 / $            - Start/end of line
gg / G           - Top/bottom of file
Ctrl+u / Ctrl+d  - Page up/down
{ / }            - Previous/next paragraph
% (on bracket)   - Jump to matching bracket
```

### Scrolling
```
Ctrl+e / Ctrl+y  - Scroll down/up one line
zz               - Center cursor on screen
zt               - Cursor to top
zb               - Cursor to bottom
```

---

## File Management

### Neo-tree (File Explorer)
```
Ctrl+n           - Toggle file explorer
```

**Inside Neo-tree:**
```
Enter            - Open file/folder
a                - Add new file
A                - Add new directory
d                - Delete
r                - Rename
c                - Copy
x                - Cut
p                - Paste
R                - Refresh
H                - Toggle hidden files
?                - Show help
```

### Buffers (Open Files)
```
:e filename      - Open file
:w               - Save file
:wq / :x         - Save and quit
:q               - Quit
:q!              - Quit without saving
:qa              - Quit all buffers
:bn              - Next buffer
:bp              - Previous buffer
:bd              - Close buffer
```

### Splits
```
:split / :sp     - Horizontal split
:vsplit / :vsp   - Vertical split
Ctrl+w h/j/k/l   - Navigate between splits
Ctrl+w =         - Equalize split sizes
Ctrl+w q         - Close current split
```

### Tabs
```
:tabnew          - New tab
gt / gT          - Next/previous tab
:tabclose        - Close tab
```

---

## Editing

### Basic Editing
```
i                - Insert before cursor
a                - Insert after cursor
I                - Insert at start of line
A                - Insert at end of line
o                - New line below
O                - New line above
x                - Delete character
dd               - Delete line
yy               - Yank (copy) line
p / P            - Paste after/before
u                - Undo
Ctrl+r           - Redo
.                - Repeat last command
```

### Text Objects
```
diw              - Delete inside word
ci"              - Change inside quotes
da(              - Delete around parentheses
vi{              - Visual select inside braces
```

### Search & Replace
```
/pattern         - Search forward
?pattern         - Search backward
n / N            - Next/previous match
*                - Search word under cursor
:%s/old/new/g    - Replace all in file
:%s/old/new/gc   - Replace all with confirmation
:noh             - Clear search highlighting
```

---

## LSP & Code Intelligence

### Navigation
```
gd               - Go to definition
gD               - Go to declaration
gr               - Show references
gi               - Go to implementation
K                - Show hover documentation
```

### Diagnostics
```
:LspInfo         - Show LSP status
[d / ]d          - Previous/next diagnostic
<leader>e        - Show diagnostic float
<leader>q        - Diagnostic list
```

### Code Actions
```
<leader>ca       - Code actions
<leader>rn       - Rename symbol
<leader>f        - Format code
```

---

## Fuzzy Finding (Telescope)

```
:Telescope find_files        - Find files
:Telescope live_grep         - Search in files
:Telescope buffers           - List open buffers
:Telescope help_tags         - Search help
:Telescope oldfiles          - Recent files
:Telescope git_files         - Git files
:Telescope git_status        - Git status
:Telescope command_history   - Command history
```

**Inside Telescope:**
```
Ctrl+n / Ctrl+p  - Next/previous result
Ctrl+c / Esc     - Close
Enter            - Open file
Ctrl+x           - Open in horizontal split
Ctrl+v           - Open in vertical split
```

---

## Git Integration (Gitsigns)

```
]c / [c          - Next/previous hunk
:Gitsigns stage_hunk         - Stage hunk
:Gitsigns undo_stage_hunk    - Undo stage
:Gitsigns reset_hunk         - Reset hunk
:Gitsigns preview_hunk       - Preview changes
:Gitsigns blame_line         - Show blame
:Gitsigns toggle_current_line_blame  - Toggle inline blame
```

---

## Zettelkasten (Telekasten)

**Leader key is `Space`**

### Note Management
```
Space + zf       - Find notes (fuzzy search)
Space + zn       - Create new note
Space + zg       - Search text in all notes (grep)
Space + zz       - Follow link under cursor
Space + zb       - Show backlinks (what links here)
```

### Daily/Weekly Notes
```
Space + zT       - Go to today's daily note
Space + zW       - Go to this week's weekly note
Space + zd       - Find daily notes
Space + zc       - Show calendar
```

### Links & Images
```
[[Note Name]]    - Create wiki-style link (type manually)
Space + zz       - Follow link (creates note if doesn't exist)
Space + zI       - Insert image link
Space + zl       - Create note from visual selection
```

### Markdown Preview
```
Space + mp       - Toggle Markdown preview in browser
Space + mg       - Glow preview in terminal (quick view)
:MarkdownPreview - Start preview
:MarkdownPreviewStop - Stop preview
```

### Obsidian Integration
```
:ObsidianOpen    - Open current note in Obsidian app
:ObsidianSearch  - Search notes via Obsidian
:ObsidianQuickSwitch - Quick switch notes
```

### Note Graph Visualization
**Custom Obsidian-like graph view built into Neovim!**
```
Space + ng       - Open note graph (shows network of linked notes)
:NoteGraph       - Same as above (custom command)
```

**Inside Note Graph:**
```
h/j/k/l          - Pan view left/down/up/right
+ / - / =        - Zoom in / out
/  or  f         - Filter notes by search term
o  or  Enter     - Open selected note
c                - Focus on current note
i                - Toggle isolated nodes
t                - Toggle transparency
w                - Open web view in browser (interactive D3.js)
q  or  Esc       - Close graph view
Mouse click      - Select node
Double click     - Open node
```

**Features:**
- Force-directed physics layout
- Shows connections between notes
- Hub nodes highlighted (highly connected notes)
- Current note highlighted in hot pink
- Filter by note name
- Interactive web export with D3.js
- Clean, Obsidian-inspired design

### Note Organization
```
Directory Structure:
~/Documents/Notes/
  ├── daily/           - Daily notes
  ├── weekly/          - Weekly notes
  ├── templates/       - Note templates
  ├── img/             - Images
  └── *.md             - Your notes
```

### Workflows

**Create a new note:**
1. Press `Space + zn`
2. Enter note title
3. Start writing

**Link notes together:**
1. Type `[[Note Name]]`
2. Press `Space + zz` to follow/create

**Daily journaling:**
1. Press `Space + zT` (creates today's note)
2. Write your journal entry
3. Link to other notes with `[[Note Name]]`

**Find & connect:**
1. Press `Space + zb` to see what links to current note
2. Press `Space + zf` to find any note
3. Press `Space + zg` to search all notes

---

## Custom Features

This config includes several custom productivity tools built specifically for your workflow.

### Custom Fuzzy Finder
**Quick multi-mode search interface**
```
Space + f        - Open search picker menu with options:
                   • Search in Current File
                   • Search Across All Files
                   • Find Files by Name
```

After selecting a mode:
- All searches are **case-insensitive** by default
- Hidden files are included in searches
- Respects `.gitignore` where appropriate

### Wishlist Management
```
Space + ww       - Open your wishlist.md file
```
Located at: `~/Documents/Notes/Parteek/wishlist.md`

### Jiu Jitsu Notes
**Specialized note-taking for BJJ training**
```
Space + jj       - Open Jiu Jitsu note picker
```

**Note types:**
- **Training Note** - Creates `training_MMDDYY.md` from template
  - Auto-fills date
  - Located in `~/Documents/Notes/jits/journal/`

- **Mindset Note** - Creates numbered `mindset-001.md` entries
  - Auto-increments numbers
  - Located in `~/Documents/Notes/jits/mindset/`

- **Custom Note** - Create any custom named note
  - You choose the name
  - Located in `~/Documents/Notes/jits/`

### Kanban Project Boards
**Manage projects with markdown kanban boards**
```
Space + kb       - Open Kanban board picker
```

**Features:**
- Lists all project boards in `~/Documents/Notes/Personal Projects/Projects/`
- "Personal Projects.md" always appears first
- Create new boards on the fly
- Default columns: Backlog → Todo → In Progress → Review → Done

**To use:**
1. Press `Space + kb`
2. Select existing board or create new
3. Edit markdown headers to organize tasks

### Daily Note Automation
**Smart daily notes with content rollover**

Commands:
```
:DailyToday              - Open today's note (creates with automation)
:DailyNew                - Force create new daily note
:DailyImportYesterday    - Import yesterday's "Tomorrow" section
```

**How it works:**
- When creating today's note, automatically pulls yesterday's "Tomorrow" section
- Places it in today's "Today's Focus" section
- Uses template from `~/Documents/Notes/templates/daily.md`
- Notes saved in `~/Documents/Notes/daily/`

**Workflow:**
1. End each day by filling the "Tomorrow" section
2. Next day, run `:DailyToday`
3. Your tomorrow tasks are now in "Today's Focus"
4. Complete the cycle by planning tomorrow again

---

## Autocomplete

### During Insert Mode
```
Ctrl+Space       - Trigger completion
Tab              - Next suggestion / Jump to next snippet field
Shift+Tab        - Previous suggestion
Enter            - Confirm selection
Ctrl+e           - Close completion menu
```

---

## Useful Commands

### Mason (LSP Installer)
```
:Mason           - Open Mason UI
:MasonInstall <name>     - Install language server
:MasonUninstall <name>   - Uninstall language server
:MasonUpdate             - Update all packages
```

**Popular LSPs to install:**
- `pyright` - Python
- `lua-language-server` - Lua
- `typescript-language-server` - JavaScript/TypeScript
- `rust-analyzer` - Rust
- `gopls` - Go
- `clangd` - C/C++
- `marksman` - Markdown

### Lazy (Plugin Manager)
```
:Lazy            - Open Lazy UI
:Lazy sync       - Install/update plugins
:Lazy clean      - Remove unused plugins
:Lazy update     - Update all plugins
:Lazy profile    - Show startup time
```

### Treesitter
```
:TSInstall <language>    - Install language parser
:TSUpdate                - Update all parsers
:TSModuleInfo            - Show installed modules
```

### Which-key Helper
```
Space            - Wait 1 second to see available keybindings
Space + z        - Wait to see all Zettelkasten commands
```

### Terminal
```
:terminal        - Open terminal in split
Ctrl+\ Ctrl+n    - Exit terminal insert mode (to navigate)
:q               - Close terminal
```

### Help System
```
:help <topic>    - Open help for topic
:help keybindings - Show keybindings help
Ctrl+]           - Follow help link
Ctrl+o           - Go back
:q               - Close help window
```

---

## Tips & Tricks

### Combining Commands
```
ggVG             - Select entire file (go top + visual line + go bottom)
ggdG             - Delete entire file
:%y              - Yank entire file to clipboard
```

### Macros
```
qa               - Start recording macro in register 'a'
q                - Stop recording
@a               - Play macro 'a'
@@               - Replay last macro
```

### Marks
```
ma               - Set mark 'a' at cursor
'a               - Jump to mark 'a'
:marks           - List all marks
```

### Registers
```
"ay              - Yank to register 'a'
"ap              - Paste from register 'a'
:registers       - Show all registers
```

### Graph Visualization

Since notes are plain Markdown in `~/Documents/Notes`:

1. **Open in Obsidian:**
   - Point Obsidian to `~/Documents/Notes`
   - View graph: `Ctrl+G` (in Obsidian)

2. **Open in Logseq:**
   - Add `~/Documents/Notes` as a folder
   - View graph in sidebar

3. **Keep editing in Neovim** while visualizing connections elsewhere!

---

## Quick Start Workflow

**1. Start Neovim:**
```bash
nvim
```

**2. Open today's daily note:**
```
:DailyToday
```
This automatically pulls yesterday's "Tomorrow" section!

**3. Quick search anything:**
```
Space + f
```
Choose from: search in file, search all files, or find files by name.

**4. Create a Zettelkasten note:**
```
Space + zn
```

**5. Open file explorer:**
```
Ctrl+n
```

**6. Manage your projects:**
```
Space + kb
```
Opens your Kanban board picker.

**7. See all available commands:**
```
Space (then wait 1 second)
```
Which-key will show you context-aware options.

---

## Getting Help

- **Custom controls guide:** `Space + h h` or `:Help` - Shows this CONTROLS.md file in popup
- **In Neovim:** `:help` or `:help <command>` - Official Neovim documentation
- **Which-key popup:** Press `Space` and wait - See context-aware keybindings
- **Telescope help:** `:Telescope help_tags` - Search all help topics
- **LSP info:** `:LspInfo` - Language server status
- **Check health:** `:checkhealth` - Diagnostic health check

---

**Happy note-taking and coding! 🚀**
