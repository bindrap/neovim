-- Custom Help Viewer
-- Shows CONTROLS.md in a floating popup window
-- Usage: Space + h h  or  :Help
-- Close with: ESC, q, or :q

local M = {}
local api = vim.api

-- Configuration
M.config = {
  controls_file = vim.fn.stdpath('config') .. '/CONTROLS.md',
  width_ratio = 0.85,   -- 85% of screen width
  height_ratio = 0.85,  -- 85% of screen height
}

-- UI state
M.ui = {
  buf = nil,
  win = nil,
}

-- Close the help window
function M.close()
  if M.ui.win and api.nvim_win_is_valid(M.ui.win) then
    api.nvim_win_close(M.ui.win, true)
  end

  if M.ui.buf and api.nvim_buf_is_valid(M.ui.buf) then
    api.nvim_buf_delete(M.ui.buf, { force = true })
  end

  M.ui = {
    buf = nil,
    win = nil,
  }
end

-- Set up keybindings for the popup
local function setup_keymaps()
  local opts = { silent = true, noremap = true, buffer = M.ui.buf }

  -- Close window with q, ESC, or :q
  vim.keymap.set('n', 'q', function() M.close() end,
    vim.tbl_extend('force', opts, { desc = 'Close help' }))
  vim.keymap.set('n', '<Esc>', function() M.close() end,
    vim.tbl_extend('force', opts, { desc = 'Close help' }))

  -- Allow :q command to close
  vim.api.nvim_buf_create_user_command(M.ui.buf, 'q', function() M.close() end, {})
end

-- Open CONTROLS.md in a floating popup window
M.show_controls = function()
  local controls_path = M.config.controls_file

  -- Check if file exists
  if vim.fn.filereadable(controls_path) == 0 then
    vim.notify('CONTROLS.md not found at: ' .. controls_path, vim.log.levels.ERROR)
    return
  end

  -- Close existing window if open
  if M.ui.win and api.nvim_win_is_valid(M.ui.win) then
    M.close()
    return
  end

  -- Read file contents
  local lines = vim.fn.readfile(controls_path)

  -- Create buffer
  M.ui.buf = api.nvim_create_buf(false, true)

  -- Set buffer content
  api.nvim_buf_set_lines(M.ui.buf, 0, -1, false, lines)

  -- Make it read-only
  api.nvim_buf_set_option(M.ui.buf, 'modifiable', false)
  api.nvim_buf_set_option(M.ui.buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(M.ui.buf, 'filetype', 'markdown')

  -- Calculate window size
  local width = math.floor(vim.o.columns * M.config.width_ratio)
  local height = math.floor(vim.o.lines * M.config.height_ratio)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  M.ui.win = api.nvim_open_win(M.ui.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Parteek\'s Config v2.0 - Controls Guide ',
    title_pos = 'center',
  })

  -- Window options for better viewing
  api.nvim_set_option_value('wrap', true, { win = M.ui.win })
  api.nvim_set_option_value('linebreak', true, { win = M.ui.win })
  api.nvim_set_option_value('cursorline', true, { win = M.ui.win })
  api.nvim_set_option_value('number', false, { win = M.ui.win })
  api.nvim_set_option_value('relativenumber', false, { win = M.ui.win })
  api.nvim_set_option_value('signcolumn', 'no', { win = M.ui.win })

  -- Set up keybindings
  setup_keymaps()

  vim.notify('Press ESC, q, or :q to close', vim.log.levels.INFO)
end

-- Keybinding: Space + h h
vim.keymap.set('n', '<leader>hh', M.show_controls, { desc = 'Show Controls Guide' })

-- User command: :Help
vim.api.nvim_create_user_command('Help', M.show_controls, { desc = 'Show Neovim Controls Guide' })

return M
