-- Centralized configuration for Neovim setup
-- This file contains paths and settings that are used across multiple modules

local M = {}

-- Default notes directory (can be changed with Space + c + d)
M.notes_dir = vim.fn.expand('/mnt/c/Users/bindrap/Documents/Obsidian Vault')

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

-- Change notes directory
function M.change_notes_dir()
  vim.ui.input({
    prompt = 'Enter new notes directory path: ',
    default = M.notes_dir,
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
          M.notes_dir = expanded_path
          vim.notify(string.format('Created and set notes directory to: %s', expanded_path), vim.log.levels.INFO)
          -- Suggest reload
          vim.notify('Restart Neovim or run :source ~/.config/nvim/init.lua to apply changes', vim.log.levels.WARN)
        else
          vim.notify('Notes directory not changed', vim.log.levels.WARN)
        end
      else
        M.notes_dir = expanded_path
        vim.notify(string.format('Notes directory set to: %s', expanded_path), vim.log.levels.INFO)
        -- Suggest reload
        vim.notify('Restart Neovim or run :source ~/.config/nvim/init.lua to apply changes', vim.log.levels.WARN)
      end
    end
  end)
end

-- Get all derived paths based on notes directory
function M.get_paths()
  return {
    home = M.notes_dir,
    dailies = M.notes_dir .. '/daily',
    weeklies = M.notes_dir .. '/weekly',
    templates = M.notes_dir .. '/templates',
    wishlist = M.notes_dir .. '/wishlist.md',
    kanban = M.notes_dir .. '/.notes',
  }
end

return M
