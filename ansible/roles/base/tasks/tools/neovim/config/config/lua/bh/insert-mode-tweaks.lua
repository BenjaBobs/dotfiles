-- nvim already has CTRL + w for delete word in backwards direction
-- so this adds CTRL + e for delete word in forward direction
vim.keymap.set("i", "<C-e>", "<C-g>u<C-o>de", { noremap = true, silent = true })

-- VSCode-like word deletion
vim.keymap.set("i", "<C-BS>", "<C-w>", { noremap = true, silent = true }) -- Delete word backwards
vim.keymap.set("i", "<C-Del>", "<C-g>u<C-o>de", { noremap = true, silent = true }) -- Delete word forwards
