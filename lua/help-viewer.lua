-- Custom Help Viewer
-- Shows CONTROLS.md for quick reference
-- Usage: Space + h h  or  :Help

local M = {}

-- Configuration
M.config = {
  controls_file = vim.fn.stdpath('config') .. '/CONTROLS.md',
}

-- Open CONTROLS.md in a split window
M.show_controls = function()
  local controls_path = M.config.controls_file

  -- Check if file exists
  if vim.fn.filereadable(controls_path) == 0 then
    vim.notify('CONTROLS.md not found at: ' .. controls_path, vim.log.levels.ERROR)
    return
  end

  -- Open in a vertical split on the right
  vim.cmd('vsplit ' .. vim.fn.fnameescape(controls_path))

  -- Make it read-only
  vim.bo.modifiable = false
  vim.bo.readonly = true

  -- Set filetype to markdown for syntax highlighting
  vim.bo.filetype = 'markdown'

  -- Optional: Set some buffer options for better viewing
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.number = false
  vim.wo.relativenumber = false

  -- Add a mapping to close with 'q'
  vim.keymap.set('n', 'q', ':q<CR>', { buffer = true, silent = true })

  vim.notify('📖 Controls Guide (press q to close)', vim.log.levels.INFO)
end

-- Keybinding: Space + h h
vim.keymap.set('n', '<leader>hh', M.show_controls, { desc = 'Show Controls Guide' })

-- User command: :Help
vim.api.nvim_create_user_command('Help', M.show_controls, { desc = 'Show Neovim Controls Guide' })

return M
