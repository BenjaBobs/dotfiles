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

-- Display whitespace
-- Nerd Font characters that render well in almost every terminal
local dots = "⋅" -- U+22C5  (middle dot)   for normal spaces
local trail = "•" -- U+2022  (bullet)       for *trailing* spaces
local tab_in = "▸" -- U+25B8  (small arrow)  for the first cell of a tab
local tab_fill = " " -- a plain space for the filler cells
vim.opt.list = true
vim.opt.listchars = {
  space = dots,
  trail = trail,
  tab = tab_in .. tab_fill,
  extends = "›", -- overflow to the right
  precedes = "‹", -- overflow to the left
  nbsp = "␣", -- non-breaking space
}
vim.cmd([[
  highlight! link NonText Whitespace        " keep them the same colour
  highlight! Whitespace gui=nocombine guifg=#5c6370 ctermfg=240
]])
