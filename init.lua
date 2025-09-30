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
        local lspconfig = require("lspconfig")

        lspconfig.pyright.setup({})
        lspconfig.lua_ls.setup({
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              diagnostics = { globals = { "vim" } },
              workspace = { library = vim.api.nvim_get_runtime_file("", true) },
            }
          }
        })
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
          transparent_background = false,
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
        local home = vim.fn.expand("~/Documents/Notes")
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
        vim.keymap.set("n", "<leader>zT", tk.goto_today, { desc = "Go to today's note" })
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
            path = "~/Documents/Notes",
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
  },
})

-- Basic Neovim settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.conceallevel = 2  -- Required for Obsidian.nvim UI features
