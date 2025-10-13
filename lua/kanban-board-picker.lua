-- Kanban Board Picker for kanban.nvim
-- Add this to your Neovim config

local M = {}

M.open_board_picker = function()
  local boards_dir = vim.fn.expand('~/Documents/Notes/Personal Projects/Projects')

  -- Get all .md files in the directory
  local files = vim.fn.glob(boards_dir .. '/*.md', false, true)

  -- Extract just the filenames
  local board_names = {}
  for _, file in ipairs(files) do
    table.insert(board_names, vim.fn.fnamemodify(file, ':t'))
  end

  -- Sort alphabetically, but put "Personal Projects.md" first
  table.sort(board_names, function(a, b)
    if a == 'Personal Projects.md' then return true end
    if b == 'Personal Projects.md' then return false end
    return a < b
  end)

  -- Add "Create New Board" option at the end
  table.insert(board_names, '+ Create New Board')

  vim.ui.select(board_names, {
    prompt = 'Select Kanban Board:',
  }, function(choice)
    if choice == '+ Create New Board' then
      -- Prompt for new board name
      vim.ui.input({ prompt = 'New Board Name: ' }, function(name)
        if name and name ~= '' then
          -- Add .md extension if not present
          if not name:match('%.md$') then
            name = name .. '.md'
          end

          local new_board_path = boards_dir .. '/' .. name

          -- Create the board with better project template
          local template = [[## Backlog

## Todo

## In Progress

## Review

## Done
]]
          local file = io.open(new_board_path, 'w')
          if file then
            file:write(template)
            file:close()
            vim.notify('Created board: ' .. name, vim.log.levels.INFO)
            vim.cmd('edit ' .. vim.fn.fnameescape(new_board_path))
          else
            vim.notify('Failed to create board: ' .. name, vim.log.levels.ERROR)
          end
        end
      end)
    elseif choice then
      local board_path = boards_dir .. '/' .. choice
      vim.cmd('edit ' .. vim.fn.fnameescape(board_path))
    end
  end)
end

-- Keybinding
vim.keymap.set('n', '<leader>kb', M.open_board_picker, { desc = 'Open Kanban Board' })

return M
