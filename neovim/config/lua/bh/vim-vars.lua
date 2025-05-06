-- paths
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

-- line numbers
vim.opt.nu = true
vim.opt.relativenumber = false

-- distance to top/bottom of screen when scrolling
vim.opt.scrolloff = 8

-- general
vim.opt.updatetime = 50
vim.opt.wrap = false

-- keys
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- clipboard / yank
vim.opt.clipboard = "unnamedplus"
--   make deletes not use clipboard
vim.keymap.set("n", "d", '"_d', { noremap = true, silent = true })
vim.keymap.set("v", "d", '"_d', { noremap = true, silent = true })

-- font stuff
vim.g.have_nerd_font = true

-- terminal colors
vim.opt.termguicolors = true

-- Smart case sensitivity in searches
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Diagnostics
-- See `:help vim.diagnostic.config()`
vim.diagnostic.config({
  underline = true,
  update_in_insert = false, -- Diagnostics are only updated when not entering text
  virtual_lines = { current_line = true },
  severity_sort = true,
  -- default for vim.diagnostic.JumpOpts sets float to false
  jump = {
    float = true,
  },
})

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
