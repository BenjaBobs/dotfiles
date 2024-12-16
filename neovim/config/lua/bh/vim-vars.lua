-- paths
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

-- line numbers
vim.opt.nu = true
vim.opt.relativenumber = true

-- distance to top/bottom of screen when scrolling
vim.scrolloff = 8

-- general
vim.opt.updatetime = 50
vim.opt.wrap = false

-- keys
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- clipboard / yank
vim.opt.clipboard = "unnamedplus"
