-- Wishlist keymap: Space w w opens wishlist.md
vim.keymap.set('n', '<leader>ww', function()
  local wishlist_path = vim.fn.expand('~/Documents/Notes/wishlist.md')

  -- Check if file exists
  if vim.fn.filereadable(wishlist_path) == 0 then
    -- Create directory if it doesn't exist
    vim.fn.mkdir(vim.fn.expand('~/Documents/Notes'), 'p')

    -- Create file with basic template
    local file = io.open(wishlist_path, 'w')
    if file then
      file:write('# Wishlist\n\n')
      file:write('## Items\n\n')
      file:write('- \n')
      file:close()
      vim.notify('📝 Created new wishlist.md', vim.log.levels.INFO)
    end
  end

  -- Open the file
  vim.cmd('edit ' .. vim.fn.fnameescape(wishlist_path))
end, { desc = 'Open wishlist' })

