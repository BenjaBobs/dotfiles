-- Incremental treesitter selection using Neovim 0.12 built-in `an`/`in`.
-- +  in normal mode: enter visual and grow
-- +  in visual mode: grow to parent node
-- -  in visual mode: shrink to child node

vim.keymap.set("n", "+", "van", { desc = "Enter Visual + grow selection", remap = true })
vim.keymap.set("x", "+", "an", { desc = "Grow selection", remap = true })
vim.keymap.set("x", "-", "in", { desc = "Shrink selection", remap = true })
