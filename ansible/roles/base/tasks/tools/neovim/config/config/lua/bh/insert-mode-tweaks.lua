-- nvim already has CTRL + w for delete word in backwards direction
-- so this adds CTRL + e for delete word in forward direction
vim.keymap.set("i", "<C-e>", "<C-g>u<C-o>de", { noremap = true, silent = true })

-- VSCode-like word deletion
vim.keymap.set("i", "<C-BS>", "<C-w>", { noremap = true, silent = true }) -- Delete word backwards
vim.keymap.set("i", "<C-Del>", "<C-g>u<C-o>de", { noremap = true, silent = true }) -- Delete word forwards

-- Nudge the cursor without leaving insert mode, for the cases mini.pairs
-- doesn't cover. `<C-g>U` (see :help i_CTRL-G_U) keeps the whole insert as one
-- unit; a bare <Left>/<Right> breaks dot-repeat, so `.` would only replay the
-- text typed after the motion.
vim.keymap.set("i", "<A-h>", "<C-g>U<Left>", { noremap = true, silent = true, desc = "Move left" })
vim.keymap.set("i", "<A-l>", "<C-g>U<Right>", { noremap = true, silent = true, desc = "Move right" })
