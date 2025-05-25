-- nvim already has CTRL + w for delete word in backwards direction
-- so this adds CTRL + e for delete word in forward direction
vim.keymap.set("i", "<C-e>", "<C-g>u<C-o>de", { noremap = true, silent = true })
