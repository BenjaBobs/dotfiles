local keymap = vim.keymap.set

keymap('n', '<leader>wh', '<cmd>split<CR>', { desc = 'Split window horizontally' })
keymap('n', '<leader>wv', '<cmd>vsplit<CR>', { desc = 'Split window vertically' })
keymap('n', '<C-S-Up>', '<C-w>k', { desc = 'Move to the window above' })
keymap('n', '<C-S-Down>', '<C-w>j', { desc = 'Move to the window below' })
keymap('n', '<C-S-Left>', '<C-w>h', { desc = 'Move to the left window' })
keymap('n', '<C-S-Right>', '<C-w>l', { desc = 'Move to the right window' })
keymap('n', '<A-S-Left>', '<C-W>>', { desc = 'Increase window width' })
keymap('n', '<A-S-Right>', '<C-W><', { desc = 'Decrease window width' })
keymap('n', '<A-S-Up>', '<C-W>+', { desc = 'Increase window height' })
keymap('n', '<A-S-Down>', '<C-W>-', { desc = 'Decrease window height' })
