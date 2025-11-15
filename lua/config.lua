-- Centralized configuration for Neovim setup
-- This file contains paths and settings that are used across multiple modules

local M = {}

-- Default directories (can be changed with Space + c + d)
-- Set via OBSIDIAN_VAULT environment variable or defaults to ~/Documents/Notes
local default_vault = os.getenv('OBSIDIAN_VAULT') or vim.fn.expand('~/Documents/Notes')

M.vault_base = default_vault
M.notes_dir = default_vault
M.parteek_dir = default_vault .. '/Parteek'
M.jits_dir = default_vault .. '/jits'
M.projects_dir = default_vault .. '/Personal Projects'

-- Detect if running on WSL
function M.is_wsl()
  local handle = io.open('/proc/version', 'r')
  if handle then
    local version = handle:read('*a')
    handle:close()
    return version:lower():match('microsoft') ~= nil or version:lower():match('wsl') ~= nil
  end
  return false
end

-- Change directory interactively
function M.change_notes_dir()
  local dir_options = {
    { name = 'Notes Directory (Main Vault)', key = 'notes_dir', current = M.notes_dir },
    { name = 'Personal Directory', key = 'parteek_dir', current = M.parteek_dir },
    { name = 'Jits Directory', key = 'jits_dir', current = M.jits_dir },
    { name = 'Projects Directory (Kanban)', key = 'projects_dir', current = M.projects_dir },
    { name = 'Vault Base Directory', key = 'vault_base', current = M.vault_base },
  }

  local choices = {}
  for i, opt in ipairs(dir_options) do
    table.insert(choices, string.format('%d. %s: %s', i, opt.name, opt.current))
  end

  vim.ui.select(choices, {
    prompt = 'Select directory to change:',
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if not idx then return end

    local selected = dir_options[idx]
    vim.ui.input({
      prompt = string.format('Enter new path for %s: ', selected.name),
      default = selected.current,
      completion = 'dir',
    }, function(new_path)
      if new_path and new_path ~= '' then
        local expanded_path = vim.fn.expand(new_path)

        -- Check if directory exists
        if vim.fn.isdirectory(expanded_path) == 0 then
          local create = vim.fn.confirm(
            string.format('Directory "%s" does not exist. Create it?', expanded_path),
            '&Yes\n&No',
            2
          )

          if create == 1 then
            vim.fn.mkdir(expanded_path, 'p')
            M[selected.key] = expanded_path
            vim.notify(string.format('Created and set %s to: %s', selected.name, expanded_path), vim.log.levels.INFO)
            vim.notify('Restart Neovim to apply changes', vim.log.levels.WARN)
          else
            vim.notify('Directory not changed', vim.log.levels.WARN)
          end
        else
          M[selected.key] = expanded_path
          vim.notify(string.format('%s set to: %s', selected.name, expanded_path), vim.log.levels.INFO)
          vim.notify('Restart Neovim to apply changes', vim.log.levels.WARN)
        end
      end
    end)
  end)
end

-- Get all derived paths
function M.get_paths()
  return {
    home = M.notes_dir,
    dailies = M.notes_dir .. '/daily',
    weeklies = M.notes_dir .. '/weekly',
    templates = M.notes_dir .. '/templates',
    parteek = M.parteek_dir,
    wishlist = M.parteek_dir .. '/wishlist.md',
    jits = M.jits_dir,
    jits_journal = M.jits_dir .. '/journal',
    jits_mindset = M.jits_dir .. '/mindset',
    projects = M.projects_dir,
    kanban = M.notes_dir .. '/.notes',
  }
end

return M
