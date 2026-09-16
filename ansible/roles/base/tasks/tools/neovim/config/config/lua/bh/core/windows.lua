local keymap = vim.keymap.set

keymap("n", "<leader>wh", "<cmd>split<CR>", { desc = "Split window horizontally" })
keymap("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Split window vertically" })
keymap("n", "<C-S-Up>", "<C-w>k", { desc = "Move to the window above" })
keymap("n", "<C-S-Down>", "<C-w>j", { desc = "Move to the window below" })
keymap("n", "<C-S-Left>", "<C-w>h", { desc = "Move to the left window" })
keymap("n", "<C-S-Right>", "<C-w>l", { desc = "Move to the right window" })
keymap("n", "<C-A-Up>", "<C-w>k", { desc = "Move to the window above" })
keymap("n", "<C-A-Down>", "<C-w>j", { desc = "Move to the window below" })
keymap("n", "<C-A-Left>", "<C-w>h", { desc = "Move to the left window" })
keymap("n", "<C-A-Right>", "<C-w>l", { desc = "Move to the right window" })
-- <A-S-Arrow> used to resize windows here. Those four keys are the treesitter
-- swap bindings in bh/plugins/text-manipulation.lua, and lazy.nvim registers
-- its key stubs during `lazy.setup()` -- which bh/init.lua runs *after* this
-- file -- so the swaps won and the resize maps had no effect anyway.

-- Highlight the current line, but only in the focused window. `cursorline` is
-- window-local, so we default it on (for the first window) and toggle it off
-- when a window loses focus / on when it gains focus. Catppuccin's CursorLine
-- is a subtle background, which is the intended effect.
vim.opt.cursorline = true

local cursorline_group = vim.api.nvim_create_augroup("bh_cursorline_active_window", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = cursorline_group,
  callback = function()
    vim.wo.cursorline = true
  end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  group = cursorline_group,
  callback = function()
    vim.wo.cursorline = false
  end,
})
