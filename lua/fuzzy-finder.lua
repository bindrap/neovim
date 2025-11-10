-- Custom fuzzy finder for looking up terms and files
local M = {}

-- Main picker function
M.open_search_picker = function()
  local search_types = {
    'Search in Current File',
    'Search Across All Files',
    'Find Files by Name',
  }

  vim.ui.select(search_types, {
    prompt = "Parteek's FuzzyFinder v1:",
  }, function(choice)
    if not choice then return end

    local builtin = require('telescope.builtin')

    if choice == 'Search in Current File' then
      builtin.current_buffer_fuzzy_find({
        prompt_title = "Search in Current File",
        sorting_strategy = "ascending",
        layout_config = {
          prompt_position = "top",
        },
        case_mode = "ignore_case",
      })
    elseif choice == 'Search Across All Files' then
      builtin.live_grep({
        prompt_title = "Search Across All Files",
        additional_args = function()
          return {"--hidden", "--no-ignore", "-i"}  -- -i for case insensitive
        end,
      })
    elseif choice == 'Find Files by Name' then
      builtin.find_files({
        prompt_title = "Find Files by Name",
        hidden = true,  -- Include hidden files
        no_ignore = false,  -- Respect .gitignore
        follow = true,  -- Follow symlinks
        case_mode = "ignore_case",
      })
    end
  end)
end

-- Keybinding
vim.keymap.set('n', '<leader>ff', M.open_search_picker, { desc = 'Open Search Picker' })

return M
