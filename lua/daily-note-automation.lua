-- Daily Note Automation
-- Automatically pulls yesterday's "Tomorrow" section into today's "Today's Focus"

local M = {}

-- Configuration
M.config = {
  notes_dir = vim.fn.expand('~/Documents/Notes'),
  daily_dir = 'daily',
  templates_dir = 'templates',
  template_file = 'daily.md',
}

-- Get the file path for a given date
local function get_daily_note_path(date_str)
  return M.config.notes_dir .. '/' .. M.config.daily_dir .. '/' .. date_str .. '.md'
end

-- Get yesterday's date in YYYY-MM-DD format
local function get_yesterday_date()
  local today = os.time()
  local yesterday = today - (24 * 60 * 60) -- Subtract 24 hours
  return os.date('%Y-%m-%d', yesterday)
end

-- Get today's date in YYYY-MM-DD format
local function get_today_date()
  return os.date('%Y-%m-%d')
end

-- Extract the "Tomorrow" section from a daily note
local function extract_tomorrow_section(file_path)
  local file = io.open(file_path, 'r')
  if not file then
    return nil
  end

  local content = file:read('*a')
  file:close()

  -- Find the "## Tomorrow" section
  local tomorrow_pattern = '## Tomorrow\n(.-)\n*$'
  local tomorrow_content = content:match(tomorrow_pattern)

  if not tomorrow_content then
    -- Try alternative pattern in case there's content after Tomorrow section
    tomorrow_pattern = '## Tomorrow\n(.-)\n##'
    tomorrow_content = content:match(tomorrow_pattern)
  end

  if tomorrow_content then
    -- Clean up the content and ensure it ends properly
    tomorrow_content = tomorrow_content:gsub('\n+$', '') -- Remove trailing newlines
    return tomorrow_content
  end

  return nil
end

-- Read the daily template
local function read_template()
  local template_path = M.config.notes_dir .. '/' .. M.config.templates_dir .. '/' .. M.config.template_file
  local file = io.open(template_path, 'r')
  if not file then
    vim.notify('Daily template not found: ' .. template_path, vim.log.levels.ERROR)
    return nil
  end

  local template = file:read('*a')
  file:close()
  return template
end

-- Create a new daily note with yesterday's Tomorrow content
function M.create_daily_note_with_yesterday_content()
  local today = get_today_date()
  local yesterday = get_yesterday_date()

  local today_path = get_daily_note_path(today)
  local yesterday_path = get_daily_note_path(yesterday)

  -- Check if today's note already exists
  local existing_file = io.open(today_path, 'r')
  if existing_file then
    existing_file:close()
    vim.notify('Daily note for ' .. today .. ' already exists', vim.log.levels.WARN)
    vim.cmd('edit ' .. vim.fn.fnameescape(today_path))
    return
  end

  -- Read the template
  local template = read_template()
  if not template then
    return
  end

  -- Replace template variables
  local title = today
  local date = os.date('%Y-%m-%d')
  local content = template:gsub('{{title}}', title)
  content = content:gsub('{{date}}', date)

  -- Extract yesterday's Tomorrow content
  local yesterday_tomorrow = extract_tomorrow_section(yesterday_path)

  if yesterday_tomorrow then
    -- Replace the "Today's Focus" section with yesterday's Tomorrow content
    local focus_pattern = '(## Today\'s Focus\n)- \n'
    local replacement = '\\1' .. yesterday_tomorrow .. '\n\n'
    content = content:gsub(focus_pattern, replacement)

    vim.notify('✅ Pulled content from yesterday\'s Tomorrow section', vim.log.levels.INFO)
  else
    vim.notify('📝 No Tomorrow section found in yesterday\'s note', vim.log.levels.INFO)
  end

  -- Write the new daily note
  local file = io.open(today_path, 'w')
  if file then
    file:write(content)
    file:close()

    -- Open the new note
    vim.cmd('edit ' .. vim.fn.fnameescape(today_path))
    vim.notify('📋 Created daily note: ' .. today, vim.log.levels.INFO)
  else
    vim.notify('Failed to create daily note: ' .. today_path, vim.log.levels.ERROR)
  end
end

-- Quick function to just open today's daily note (create if doesn't exist)
function M.open_today_note()
  local today = get_today_date()
  local today_path = get_daily_note_path(today)

  -- Check if today's note exists
  local file = io.open(today_path, 'r')
  if file then
    file:close()
    vim.cmd('edit ' .. vim.fn.fnameescape(today_path))
  else
    -- Create it with yesterday's content
    M.create_daily_note_with_yesterday_content()
  end
end

-- Function to manually pull yesterday's Tomorrow into current note
function M.import_yesterday_tomorrow()
  local current_file = vim.fn.expand('%:p')
  local daily_dir_path = M.config.notes_dir .. '/' .. M.config.daily_dir .. '/'

  -- Check if current file is a daily note
  if not current_file:match(daily_dir_path) then
    vim.notify('Current file is not a daily note', vim.log.levels.WARN)
    return
  end

  local yesterday = get_yesterday_date()
  local yesterday_path = get_daily_note_path(yesterday)

  local yesterday_tomorrow = extract_tomorrow_section(yesterday_path)

  if yesterday_tomorrow then
    -- Get current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1]

    -- Insert yesterday's tomorrow content at current cursor position
    local lines = vim.split(yesterday_tomorrow, '\n')
    vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, lines)

    vim.notify('✅ Imported yesterday\'s Tomorrow section', vim.log.levels.INFO)
  else
    vim.notify('❌ No Tomorrow section found in yesterday\'s note', vim.log.levels.WARN)
  end
end

-- Create user commands for easy access
vim.api.nvim_create_user_command('DailyToday', function()
  M.open_today_note()
end, { desc = 'Open today\'s daily note with automation' })

vim.api.nvim_create_user_command('DailyImportYesterday', function()
  M.import_yesterday_tomorrow()
end, { desc = 'Import yesterday\'s Tomorrow section' })

vim.api.nvim_create_user_command('DailyNew', function()
  M.create_daily_note_with_yesterday_content()
end, { desc = 'Create new daily note with yesterday\'s Tomorrow content' })

return M