-- Daily Note Automation
-- Automatically pulls yesterday's "Tomorrow" section into today's "Today's Focus"

local M = {}

-- Configuration
M.config = {
  notes_dir = vim.fn.expand('/mnt/c/Users/bindrap/Documents/Obsidian Vault'),
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
    -- Debug: file doesn't exist
    vim.notify('Debug: Yesterday\'s note not found at: ' .. file_path, vim.log.levels.DEBUG)
    return nil
  end

  local content = file:read('*a')
  file:close()

  -- Find the "## Tomorrow" section - use string manipulation instead of pattern
  local tomorrow_start = content:find('## Tomorrow\n')
  if not tomorrow_start then
    -- Try without newline in case of different line endings
    tomorrow_start = content:find('## Tomorrow')
    if not tomorrow_start then
      vim.notify('Debug: No "## Tomorrow" section found in yesterday\'s note', vim.log.levels.DEBUG)
      return nil
    end
    -- Adjust to skip past the heading
    tomorrow_start = tomorrow_start + 11  -- Length of "## Tomorrow"
    -- Skip to next line
    local newline = content:find('\n', tomorrow_start)
    if newline then
      tomorrow_start = newline
    end
  else
    tomorrow_start = tomorrow_start + 11  -- Position after "## Tomorrow"
  end

  -- Find the next ## section or end of file
  local next_section = content:find('\n##', tomorrow_start + 1)

  local tomorrow_content
  if next_section then
    -- Extract from start of Tomorrow content to next section
    tomorrow_content = content:sub(tomorrow_start + 1, next_section - 1)
  else
    -- Extract from start of Tomorrow content to end of file
    tomorrow_content = content:sub(tomorrow_start + 1)
  end

  if tomorrow_content then
    -- Clean up the content: remove leading/trailing whitespace but keep structure
    tomorrow_content = tomorrow_content:gsub('^%s+', ''):gsub('%s+$', '')
    if tomorrow_content ~= '' then
      return tomorrow_content
    end
  end

  return nil
end

-- Default template if file doesn't exist
local function get_default_template()
  return [=[# {{title}}

**Date:** {{date}}

---
[[Personal Projects]]

## Today's Focus
-

## Notes
-


## Tasks
-

## Achievements
-

## Tomorrow
-

]=]
end

-- Read the daily template
local function read_template()
  local template_path = M.config.notes_dir .. '/' .. M.config.templates_dir .. '/' .. M.config.template_file
  local file = io.open(template_path, 'r')
  if not file then
    vim.notify('Daily template not found at: ' .. template_path .. ', using default template', vim.log.levels.WARN)
    return get_default_template()
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

  -- Ensure daily directory exists
  local daily_dir = M.config.notes_dir .. '/' .. M.config.daily_dir
  vim.fn.mkdir(daily_dir, 'p')

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
    -- Use string.find and string.sub for more reliable replacement
    local focus_start = content:find('## Today\'s Focus\n')
    if focus_start then
      -- Find the next ## section after Today's Focus
      local next_section = content:find('\n##', focus_start + 17)  -- +17 to skip past "## Today's Focus\n"

      if next_section then
        -- Replace everything between "## Today's Focus\n" and the next section
        local before = content:sub(1, focus_start + 16)  -- Include "## Today's Focus\n"
        local after = content:sub(next_section)
        content = before .. yesterday_tomorrow .. '\n' .. after
      else
        -- If no next section, replace to end of file
        content = content:sub(1, focus_start + 16) .. yesterday_tomorrow .. '\n'
      end

      vim.notify('✅ Pulled content from yesterday\'s Tomorrow section', vim.log.levels.INFO)
    else
      vim.notify('⚠️  Could not find Today\'s Focus section in template', vim.log.levels.WARN)
    end
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