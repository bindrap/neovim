-- Wishlist keymap: Space w w opens wishlist.md
vim.keymap.set('n', '<leader>ww', function()
  vim.cmd('edit ~/Documents/Notes/Parteek/wishlist.md')
end, { desc = 'Open wishlist' })
