------------------
-- This makes neovim just use clipboard instead of registers
-- because clipboard history is a thing so it becomes easier
-- to interact with the rest of the OS.
------------------

-- use system clipboard for yanking
vim.opt.clipboard = "unnamedplus"

-- Delete/cut to black hole by default (except for x/X)
local function map(mode, lhs, rhs)
  vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true })
end

-- Normal + Visual modes
local modes = { "n", "v" }

-- Remap delete/change to not touch clipboard
for _, m in ipairs(modes) do
  map(m, "d", '"_d')
  map(m, "D", '"_D')
  map(m, "c", '"_c')
  map(m, "C", '"_C')
  map(m, "s", '"_s')
  map(m, "S", '"_S')
end

-- Keep x/X as clipboard cut
map("n", "x", '"+x')
map("n", "X", '"+X')
map("v", "x", '"+x')
map("v", "X", '"+X')

-- Add a motion-enabled version of x for cutting
vim.keymap.set("n", "gx", '"+d', { noremap = true })

-- Make pasting in visual mode not replace clipboard
map("v", "p", "P") -- p replaces, but P doesn't

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
