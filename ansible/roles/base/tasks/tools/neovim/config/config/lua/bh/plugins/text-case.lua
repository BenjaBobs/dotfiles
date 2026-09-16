------------------
-- Case conversion: snake_case, PascalCase, kebab-case, CONSTANT_CASE, ...
--
-- Vim's built-ins only reach upper/lower/toggle (`gU`, `gu`, `g~`), and since
-- bh/undo.lua unmaps `u`/`U` in visual mode those `g`-prefixed forms are the
-- only built-in route. Everything structural comes from here.
--
-- The plugin's own keymaps are deliberately off. They hang off `ga`, which is
-- the built-in "show the character code under the cursor" (decimal/hex/octal)
-- -- worth keeping for chasing encoding and invisible-character problems.
------------------

-- Offered in the picker, roughly most- to least-used. The full set the plugin
-- ships is larger (comma, title-dash, upper/lower phrase); adding one here is
-- enough to surface it, no other wiring needed.
local methods = {
  "to_snake_case",
  "to_camel_case",
  "to_pascal_case",
  "to_dash_case",
  "to_constant_case",
  "to_title_case",
  "to_upper_case",
  "to_lower_case",
  "to_dot_case",
  "to_path_case",
  "to_phrase_case",
}

-- text-case ships a Telescope extension and nothing else, but the picker is the
-- shallow part: every conversion is a table carrying `method_name` plus a `desc`
-- that is literally the case rendered in itself ("to_snake_case", "ToPascalCase",
-- "to-dash-case"), which makes a self-documenting menu. Snacks already replaces
-- `vim.ui.select` (see snacks.lua: `picker = { enabled = true }`), so selecting
-- through it lands in the same UI as every other picker here -- no bridge.
local function pick_case()
  local textcase = require("textcase")

  local mode = vim.api.nvim_get_mode().mode
  local is_visual = mode == "v" or mode == "V" or mode == "\22"

  -- `'<`/`'>` are only written when visual mode is *left*, and the `gv` in the
  -- callback below reads them. Leaving now -- synchronously, hence the "x" flag
  -- -- sets them before the picker steals focus, rather than trusting the picker
  -- to knock us out of visual mode first.
  if is_visual then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end

  local items = vim.tbl_map(function(name)
    return textcase.api[name]
  end, methods)

  vim.ui.select(items, {
    prompt = is_visual and "Convert selection to" or "Convert word to",
    format_item = function(item)
      return item.desc
    end,
  }, function(choice)
    if not choice then
      return
    end
    -- `quick_replace` branches on the mode it finds when called, so the
    -- selection has to be back before it runs: visual for a selection, plain
    -- normal for the word under the cursor.
    if is_visual then
      vim.cmd("normal! gv")
    end
    textcase.quick_replace(choice.method_name)
  end)
end

return {
  "johmsalas/text-case.nvim",
  -- No release tags at all; pin the current main commit.
  commit = "e898cfd46fa6cde0e83abb624a16e67d2ffc6457",
  -- `:Subs` comes from the plugin's own plugin/start.vim -- a project-wide
  -- rename that keeps each occurrence's casing (`:%Subs/old_name/new_name/`).
  cmd = { "Subs" },
  keys = {
    {
      "<leader>cc",
      pick_case,
      mode = { "n", "x" },
      desc = "[C]ase convert",
    },
  },
  config = function()
    require("textcase").setup({ default_keymappings_enabled = false })
  end,
}
