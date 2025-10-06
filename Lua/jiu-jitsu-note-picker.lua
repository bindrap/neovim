-- Jiu Jitsu Note Picker
-- Add this to your Neovim config

local M = {}

M.open_note_picker = function()
  local notes_dir = vim.fn.expand('~/Documents/Notes/jits')
  local templates_dir = vim.fn.expand('~/Documents/Notes/templates')

  -- Ensure directories exist
  vim.fn.mkdir(notes_dir, 'p')
  vim.fn.mkdir(notes_dir .. '/journal', 'p')
  vim.fn.mkdir(notes_dir .. '/mindset', 'p')

  local note_types = {
    'Training Note',
    'Mindset Note',
    'Make One (custom)',
  }

  vim.ui.select(note_types, {
    prompt = 'Select Jiu Jitsu Note:',
  }, function(choice)
    if not choice then return end

    if choice == 'Make One (custom)' then
      -- Prompt for custom note name
      vim.ui.input({ prompt = 'Note Name: ' }, function(name)
        if name and name ~= '' then
          -- Add .md extension if not present
          if not name:match('%.md$') then
            name = name .. '.md'
          end

          local note_path = notes_dir .. '/' .. name
          vim.cmd('edit ' .. vim.fn.fnameescape(note_path))
          vim.notify('Created note: ' .. name, vim.log.levels.INFO)
        end
      end)
    elseif choice == 'Training Note' then
      -- Generate date in format MMDDYY (e.g., 100525 for October 5, 2025)
      local date = os.date('%m%d%y')
      local note_name = 'training_' .. date .. '.md'
      local note_path = notes_dir .. '/journal/' .. note_name

      -- Read template
      local template_path = templates_dir .. '/jits_training.md'
      local template_file = io.open(template_path, 'r')
      local template = ''
      if template_file then
        template = template_file:read('*a')
        template_file:close()

        -- Replace {{date}} with actual date
        local full_date = os.date('%b %d, %Y')  -- e.g., "Oct 5, 2025"
        template = template:gsub('{{date}}', full_date)
      end

      -- Write template if file doesn't exist
      local file = io.open(note_path, 'r')
      if not file then
        file = io.open(note_path, 'w')
        if file then
          file:write(template)
          file:close()
        end
      else
        file:close()
      end

      vim.cmd('edit ' .. vim.fn.fnameescape(note_path))
      vim.notify('Created training note: ' .. note_name, vim.log.levels.INFO)
    elseif choice == 'Mindset Note' then
      -- Find the latest mindset note number
      local mindset_dir = notes_dir .. '/mindset'
      local files = vim.fn.glob(mindset_dir .. '/mindset-*.md', false, true)

      local max_num = 0
      for _, file in ipairs(files) do
        local filename = vim.fn.fnamemodify(file, ':t')
        local num = filename:match('mindset%-(%d+)%.md')
        if num then
          max_num = math.max(max_num, tonumber(num))
        end
      end

      -- Create next mindset note
      local next_num = max_num + 1
      local note_name = string.format('mindset-%03d.md', next_num)
      local note_path = mindset_dir .. '/' .. note_name

      -- Read template
      local template_path = templates_dir .. '/jits_mindset.md'
      local template_file = io.open(template_path, 'r')
      local template = ''
      if template_file then
        template = template_file:read('*a')
        template_file:close()
      end

      -- Write template if file doesn't exist
      local file = io.open(note_path, 'r')
      if not file then
        file = io.open(note_path, 'w')
        if file then
          file:write(template)
          file:close()
        end
      else
        file:close()
      end

      vim.cmd('edit ' .. vim.fn.fnameescape(note_path))
      vim.notify('Created mindset note: ' .. note_name, vim.log.levels.INFO)
    end
  end)
end

-- Keybinding
vim.keymap.set('n', '<leader>jj', M.open_note_picker, { desc = 'Jiu Jitsu Note' })

return M
