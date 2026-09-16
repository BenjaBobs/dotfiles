------------------
-- Everything under lua/bh/ is grouped by what it does when required:
--
--   core/     -- requiring it changes the editor: options, keymaps, autocmds
--   lib/      -- pure and inert until called: colour, encoding, utils
--   features/ -- on-demand tools with an API, each owning its own keymap
--   plugins/  -- lazy.nvim specs, loaded by the import below
--
-- Only core/ and the feature keymaps need requiring up front; everything else
-- is pulled in on first use.
------------------

for _, mod in ipairs({
  "core.vim-vars",
  "core.windows",
  "core.clipboard",
  "core.undo",
  "core.insert-mode-tweaks",
  "core.rainbow-variables",
  "core.type-colors",
  "core.scroll-past-eof",
  -- Feature entry points: each binds its own key and loads the rest lazily.
  "features.explain.keys",
  "features.transform.keys",
}) do
  require("bh." .. mod)
end

--/telesco Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazy_tag = "v11.17.5"
local lazy_commit = "85c7ff3711b730b4030d03144f6db6375044ae82"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=" .. lazy_tag, lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    -- Only wait for a keypress when running interactively; in headless/CI runs
    -- there is no UI and getchar() would block forever.
    if #vim.api.nvim_list_uis() > 0 then
      vim.fn.getchar()
    end
    os.exit(1)
  end
end

local installed_lazy_commit = vim.fn.system({ "git", "-C", lazypath, "rev-parse", "HEAD" }):gsub("%s+$", "")
if installed_lazy_commit ~= lazy_commit then
  local out = vim.fn.system({ "git", "-C", lazypath, "checkout", lazy_commit })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to pin lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    -- Only wait for a keypress when running interactively; in headless/CI runs
    -- there is no UI and getchar() would block forever.
    if #vim.api.nvim_list_uis() > 0 then
      vim.fn.getchar()
    end
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "bh.plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- Keep updates explicit; pins are changed intentionally after review.
  checker = { enabled = false },
})
