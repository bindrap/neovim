-- Custom Help Viewer
-- Shows CONTROLS.md in a floating popup window
-- Usage: Space + h h  or  :Help
-- Close with: ESC or q
-- Search with: / (then type search term)
-- Navigate: n (next), N (previous)

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

-- Search state
M.search = {
  term = nil,
  matches = {},
  current_index = 0,
  namespace = vim.api.nvim_create_namespace('help_viewer_search'),
}

-- Clear search highlights
local function clear_search()
  if M.ui.buf and api.nvim_buf_is_valid(M.ui.buf) then
    api.nvim_buf_clear_namespace(M.ui.buf, M.search.namespace, 0, -1)
  end
  M.search.matches = {}
  M.search.current_index = 0
end

-- Find all matches for a search term
local function find_matches(term)
  if not term or term == '' then return end

  clear_search()
  M.search.term = term

  local lines = api.nvim_buf_get_lines(M.ui.buf, 0, -1, false)
  local case_sensitive = term:match('[A-Z]') ~= nil  -- Case sensitive if term has uppercase
  local search_term = case_sensitive and term or term:lower()

  for line_num, line in ipairs(lines) do
    local search_line = case_sensitive and line or line:lower()
    local start_col = 1

    while true do
      local match_start, match_end = search_line:find(search_term, start_col, true)
      if not match_start then break end

      table.insert(M.search.matches, {
        line = line_num - 1,  -- 0-indexed
        col_start = match_start - 1,  -- 0-indexed
        col_end = match_end,
      })

      start_col = match_end + 1
    end
  end

  if #M.search.matches > 0 then
    M.search.current_index = 1
    highlight_matches()
    jump_to_match(1)
    vim.notify(string.format('Found %d matches for "%s"', #M.search.matches, term), vim.log.levels.INFO)
  else
    vim.notify(string.format('No matches found for "%s"', term), vim.log.levels.WARN)
  end
end

-- Highlight all matches
function highlight_matches()
  clear_search()

  for i, match in ipairs(M.search.matches) do
    local hl_group = (i == M.search.current_index) and 'IncSearch' or 'Search'
    api.nvim_buf_add_highlight(
      M.ui.buf,
      M.search.namespace,
      hl_group,
      match.line,
      match.col_start,
      match.col_end
    )
  end
end

-- Jump to a specific match
function jump_to_match(index)
  if #M.search.matches == 0 then return end

  local match = M.search.matches[index]
  api.nvim_win_set_cursor(M.ui.win, { match.line + 1, match.col_start })

  -- Center the match in the window
  vim.cmd('normal! zz')
end

-- Search forward (next match)
function M.search_next()
  if #M.search.matches == 0 then
    vim.notify('No active search. Press / to search', vim.log.levels.WARN)
    return
  end

  M.search.current_index = M.search.current_index + 1
  if M.search.current_index > #M.search.matches then
    M.search.current_index = 1  -- Wrap to first match
  end

  highlight_matches()
  jump_to_match(M.search.current_index)
  vim.notify(string.format('Match %d of %d', M.search.current_index, #M.search.matches), vim.log.levels.INFO)
end

-- Search backward (previous match)
function M.search_prev()
  if #M.search.matches == 0 then
    vim.notify('No active search. Press / to search', vim.log.levels.WARN)
    return
  end

  M.search.current_index = M.search.current_index - 1
  if M.search.current_index < 1 then
    M.search.current_index = #M.search.matches  -- Wrap to last match
  end

  highlight_matches()
  jump_to_match(M.search.current_index)
  vim.notify(string.format('Match %d of %d', M.search.current_index, #M.search.matches), vim.log.levels.INFO)
end

-- Start a new search
function M.start_search()
  vim.ui.input({
    prompt = 'Search: ',
    default = M.search.term or '',
  }, function(input)
    if input and input ~= '' then
      find_matches(input)
    end
  end)
end

-- Close the help window
function M.close()
  -- Clear search state
  clear_search()
  M.search.term = nil

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

  -- Close window with q or ESC
  vim.keymap.set('n', 'q', function() M.close() end,
    vim.tbl_extend('force', opts, { desc = 'Close help' }))
  vim.keymap.set('n', '<Esc>', function() M.close() end,
    vim.tbl_extend('force', opts, { desc = 'Close help' }))

  -- Search functionality
  vim.keymap.set('n', '/', function() M.start_search() end,
    vim.tbl_extend('force', opts, { desc = 'Search in help' }))
  vim.keymap.set('n', 'n', function() M.search_next() end,
    vim.tbl_extend('force', opts, { desc = 'Next search result' }))
  vim.keymap.set('n', 'N', function() M.search_prev() end,
    vim.tbl_extend('force', opts, { desc = 'Previous search result' }))
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

  vim.notify('Press / to search, n/N to navigate, ESC or q to close', vim.log.levels.INFO)
end

-- Keybinding: Space + h h
vim.keymap.set('n', '<leader>hh', M.show_controls, { desc = 'Show Controls Guide' })

-- User command: :Help
vim.api.nvim_create_user_command('Help', M.show_controls, { desc = 'Show Neovim Controls Guide' })

return M
