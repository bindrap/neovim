-- Set leader key (must be set before lazy.nvim)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim and plugins
require("lazy").setup({
  spec = {
    -- ✅ Syntax highlighting & indentation
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = { "lua", "python", "javascript", "html", "css", "json" },
          highlight = { enable = true },
          indent = { enable = true },
        })
      end,
    },

    -- ✅ Autocomplete + snippets
    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "rafamadriz/friendly-snippets",
      },
      config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")

        require("luasnip.loaders.from_vscode").lazy_load()

        cmp.setup({
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              else
                fallback()
              end
            end, { "i", "s" }),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" },
            { name = "luasnip" },
            { name = "buffer" },
            { name = "path" },
          }),
        })
      end,
    },

    -- ✅ LSP (smart completion & diagnostics)
    {
      "neovim/nvim-lspconfig",
      config = function()
        vim.lsp.config("pyright", {})
        vim.lsp.config("lua_ls", {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = { library = vim.api.nvim_get_runtime_file("", true) },
            }
          }
        })
        vim.lsp.enable("pyright")
        vim.lsp.enable("lua_ls")
      end,
    },

    -- ✅ File/Folder icons
    {
      "nvim-tree/nvim-web-devicons",
      config = function()
        require("nvim-web-devicons").setup({
          override = {},
          default = true,
        })
      end,
    },

    -- ✅ Status line
    {
      "nvim-lualine/lualine.nvim",
      config = function()
        require("lualine").setup()
      end,
    },

    -- ✅ Fuzzy finder
    { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },

    -- ✅ Git integration
    {
      "lewis6991/gitsigns.nvim",
      config = function()
        require("gitsigns").setup()
      end,
    },

    -- ✅ Keymap helper (VSCode-like popup)
    { "folke/which-key.nvim", config = true },

    -- ✅ LSP/DAP/Linter installer
    { "williamboman/mason.nvim", config = true },

    -- ✅ Color scheme
    {
      "catppuccin/nvim",
      name = "catppuccin",
      priority = 1000,
      config = function()
        require("catppuccin").setup({
          flavour = "mocha", -- latte, frappe, macchiato, mocha
          transparent_background = true,
          integrations = {
            treesitter = true,
            telescope = true,
            gitsigns = true,
            nvimtree = true,
            which_key = true,
          },
        })
        vim.cmd.colorscheme("catppuccin")
      end,
    },

    -- ✅ File explorer (Neo-tree)
    {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
      },
      config = function()
        -- Toggle Neo-tree with Ctrl+n
        vim.keymap.set("n", "<C-n>", ":Neotree toggle<CR>", { silent = true })
      end,
    },

    -- ✅ Luarocks support
    {
      "vhyrro/luarocks.nvim",
      priority = 1000,
      config = true,
    },

    -- ✅ Image display
    {
      "3rd/image.nvim",
      dependencies = { "vhyrro/luarocks.nvim" },
      opts = {
        backend = "kitty", -- or "ueberzug"
        max_height_window_percentage = 50,
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.svg" },
      },
    },

    -- ✅ Zettelkasten note-taking (Telekasten)
    {
      "renerocksai/telekasten.nvim",
      dependencies = { "nvim-telescope/telescope.nvim" },
      config = function()
        local home = "/home/parteek/Documents/Notes"
        require("telekasten").setup({
          home = home,
          -- Daily notes
          dailies = home .. "/" .. "daily",
          weeklies = home .. "/" .. "weekly",
          templates = home .. "/" .. "templates",

          -- Image support (auto-paste from clipboard)
          image_subdir = "img",

          -- File extension
          extension = ".md",

          -- Template for new notes
          template_new_note = home .. "/" .. "templates/new_note.md",
          template_new_daily = home .. "/" .. "templates/daily.md",
          template_new_weekly = home .. "/" .. "templates/weekly.md",

          -- Wiki-style links
          follow_creates_nonexisting = true,
          dailies_create_nonexisting = true,
          weeklies_create_nonexisting = true,

          -- Calendar integration
          plug_into_calendar = true,
          calendar_opts = {
            weeknm = 4,
            calendar_monday = 1,
            calendar_mark = "left-fit",
          },
        })

        -- Keybindings
        local tk = require("telekasten")
        vim.keymap.set("n", "<leader>zf", tk.find_notes, { desc = "Find notes" })
        vim.keymap.set("n", "<leader>zd", tk.find_daily_notes, { desc = "Find daily notes" })
        vim.keymap.set("n", "<leader>zg", tk.search_notes, { desc = "Search in notes" })
        vim.keymap.set("n", "<leader>zz", tk.follow_link, { desc = "Follow link" })
        vim.keymap.set("n", "<leader>zt", tk.goto_today, { desc = "Go to today's note" })
        vim.keymap.set("n", "<leader>zW", tk.goto_thisweek, { desc = "Go to this week's note" })
        vim.keymap.set("n", "<leader>zn", tk.new_note, { desc = "New note" })
        vim.keymap.set("n", "<leader>zc", tk.show_calendar, { desc = "Show calendar" })
        vim.keymap.set("n", "<leader>zb", tk.show_backlinks, { desc = "Show backlinks" })
        vim.keymap.set("n", "<leader>zI", tk.insert_img_link, { desc = "Insert image link" })

        -- Create link from visual selection
        vim.keymap.set("v", "<leader>zl", function()
          tk.new_note()
        end, { desc = "Create note from selection" })
      end,
    },

    -- ✅ Calendar for daily notes
    {
      "renerocksai/calendar-vim",
    },

    -- ✅ Markdown preview in browser
    {
      "iamcco/markdown-preview.nvim",
      cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
      build = "cd app && npm install",
      init = function()
        vim.g.mkdp_filetypes = { "markdown" }
      end,
      ft = { "markdown" },
      keys = {
        { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
      },
    },

    -- ✅ Terminal markdown preview (Glow)
    {
      "ellisonleao/glow.nvim",
      config = true,
      cmd = "Glow",
      keys = {
        { "<leader>mg", "<cmd>Glow<cr>", desc = "Glow Preview" },
      },
    },

    -- ✅ Obsidian integration (graph view support)
    {
      "epwalsh/obsidian.nvim",
      version = "*",
      lazy = true,
      ft = "markdown",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      opts = {
        workspaces = {
          {
            name = "notes",
            path = "/home/parteek/Documents/Notes",
          },
        },
        -- Disable most obsidian.nvim features since we use Telekasten
        disable_frontmatter = true,
        daily_notes = {
          folder = "daily",
        },
        -- Use Obsidian for graph view only
        follow_url_func = function(url)
          vim.fn.jobstart({"xdg-open", url})
        end,
      },
    },

    -- ✅ Telescope FZF native (performance boost)
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      config = function()
        require("telescope").load_extension("fzf")
      end,
    },

    -- ✅ Sidebar (LSP symbol navigator)
    {
      "sidebar-nvim/sidebar.nvim",
      config = function()
        require("sidebar-nvim").setup({
          open = false,
          side = "right",
          sections = { "datetime", "git", "diagnostics", "symbols" },
        })
        vim.keymap.set("n", "<leader>ss", "<cmd>SidebarNvimToggle<cr>", { desc = "Toggle Sidebar" })
      end,
    },

    -- ✅ Indent guides (visualize indentation)
    {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      config = function()
        require("ibl").setup({
          indent = { char = "│" },
          scope = { enabled = true, show_start = true, show_end = true },
        })
      end,
    },

    -- ✅ Color highlighter (show colors in code)
    {
      "norcalli/nvim-colorizer.lua",
      config = function()
        require("colorizer").setup()
      end,
    },

    -- ✅ Smooth scrolling
    {
      "karb94/neoscroll.nvim",
      config = function()
        require("neoscroll").setup()
      end,
    },

    -- ✅ Dashboard (startup screen)
    {
      "goolord/alpha-nvim",
      config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        dashboard.section.header.val = {
          "",
          "    ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
          "    ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
          "    ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
          "    ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
          "    ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
          "    ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
          "",
          "              Parteek's Config v1.3",
          "",
        }

        dashboard.section.buttons.val = {
          dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
          dashboard.button("n", "  New note", ":lua require('telekasten').new_note()<CR>"),
          dashboard.button("t", "  Today's note", ":lua require('telekasten').goto_today()<CR>"),
          dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
          dashboard.button("c", "  Config", ":e ~/.config/nvim/init.lua<CR>"),
          dashboard.button("q", "  Quit", ":qa<CR>"),
        }

        alpha.setup(dashboard.config)
      end,
    },

    -- ✅ Better UI components
    {
      "stevearc/dressing.nvim",
      config = function()
        require("dressing").setup({
          input = { enabled = true },
          select = { enabled = true, backend = { "telescope", "builtin" } },
        })
      end,
    },

    -- ✅ Notifications (pretty popups)
    {
      "rcarriga/nvim-notify",
      config = function()
        vim.notify = require("notify")
        require("notify").setup({
          stages = "fade",
          timeout = 3000,
          background_colour = "#000000",
        })
      end,
    },

    -- ✅ Buffer tabs (shows open files as tabs)
    {
      "akinsho/bufferline.nvim",
      dependencies = "nvim-tree/nvim-web-devicons",
      config = function()
        require("bufferline").setup({
          options = {
            mode = "buffers",
            diagnostics = "nvim_lsp",
            show_buffer_close_icons = true,
            show_close_icon = false,
            separator_style = "slant",
          },
        })
        -- Buffer navigation
        vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
        vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
        vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Close buffer" })
      end,
    },

    -- ✅ Highlight word under cursor
    {
      "RRethy/vim-illuminate",
      config = function()
        require("illuminate").configure({
          delay = 200,
          under_cursor = true,
        })
      end,
    },

    -- ✅ Autopairs (auto-close brackets, quotes)
    {
      "windwp/nvim-autopairs",
      config = function()
        require("nvim-autopairs").setup({})
        -- Integrate with nvim-cmp
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        local cmp = require("cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end,
    },

    -- ✅ Todo comments highlighting
    {
      "folke/todo-comments.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("todo-comments").setup()
        vim.keymap.set("n", "<leader>ft", ":TodoTelescope<CR>", { desc = "Find todos" })
      end,
    },

    -- ✅ Better markdown bullet handling
    {
      "dkarter/bullets.vim",
      ft = { "markdown", "text" },
    },

    -- ✅ Kanban board picker (markdown-based)
    {
      "nvim-lua/plenary.nvim",
      lazy = false,
      config = function()
        -- Load board picker
        require('kanban-board-picker')
        -- Load jiu jitsu note picker
        require('jiu-jitsu-note-picker')
      end,
    },

  },
})

-- Basic Neovim settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.conceallevel = 2  -- Required for Obsidian.nvim UI features
vim.opt.swapfile = false  -- Disable swap files

-- Markdown folding settings (using treesitter)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false  -- Don't fold by default for non-markdown
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99  -- Start with folds open

-- Bullets.vim configuration
vim.g.bullets_enabled_file_types = { 'markdown', 'text', 'gitcommit' }
vim.g.bullets_enable_in_empty_buffers = 0
vim.g.bullets_nested_checkboxes = 1

-- Custom fold expression for markdown (Obsidian-like)
function _G.MarkdownFoldExpr()
  local lnum = vim.v.lnum
  local line = vim.fn.getline(lnum)
  local nextline = vim.fn.getline(lnum + 1)

  -- Headings create folds
  local heading = line:match("^(#+)%s")
  if heading then
    return ">" .. tostring(#heading)
  end

  -- Empty lines have no fold
  if line:match("^%s*$") then
    return "0"
  end

  -- Get current line's indent level (matches bullets, numbered lists, and checkboxes)
  local curr_indent = line:match("^(%s*)[-%*+]%s") or line:match("^(%s*)%d+%.%s") or line:match("^(%s*)%[.%]%s")

  if curr_indent then
    local curr_level = math.floor(#curr_indent / 2) + 1

    -- Check next line
    local next_indent = nextline:match("^(%s*)[-%*+]%s") or nextline:match("^(%s*)%d+%.%s") or nextline:match("^(%s*)%[.%]%s")
    local is_next_empty = nextline:match("^%s*$")
    local is_next_heading = nextline:match("^#+%s")

    -- If next line is more indented, start a fold at current level
    if next_indent and #next_indent > #curr_indent then
      return ">" .. tostring(curr_level)
    end

    -- If next line is same or less indented, empty, or heading - stay at current level
    return tostring(curr_level)
  end

  return "="
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.MarkdownFoldExpr()"
    vim.opt_local.foldenable = true
    vim.opt_local.foldlevel = 99  -- Start with all folds open

    -- Tab to indent list items (insert mode)
    vim.keymap.set("i", "<Tab>", function()
      local line = vim.api.nvim_get_current_line()
      if line:match("^%s*[-*+]%s") or line:match("^%s*%d+%.%s") then
        return "<C-t>"
      else
        return "<Tab>"
      end
    end, { buffer = true, expr = true })

    -- Shift-Tab to dedent list items (insert mode)
    vim.keymap.set("i", "<S-Tab>", function()
      local line = vim.api.nvim_get_current_line()
      if line:match("^%s*[-*+]%s") or line:match("^%s*%d+%.%s") then
        return "<C-d>"
      else
        return "<S-Tab>"
      end
    end, { buffer = true, expr = true })

    -- Tab in normal/visual mode for indenting
    vim.keymap.set("n", "<Tab>", ">>", { buffer = true })
    vim.keymap.set("n", "<S-Tab>", "<<", { buffer = true })
    vim.keymap.set("v", "<Tab>", ">gv", { buffer = true })
    vim.keymap.set("v", "<S-Tab>", "<gv", { buffer = true })
  end,
})

-- Auto-insert kanban template for new .md files in .notes folder
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*/Documents/Notes/.notes/*.md",
  callback = function()
    local lines = {
      "## Backlog",
      "",
      "## Todo",
      "",
      "## In Progress",
      "",
      "## Review",
      "",
      "## Done",
    }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end,
})

-- Load custom keymaps
require('wishlist')
require('fuzzy-finder')
