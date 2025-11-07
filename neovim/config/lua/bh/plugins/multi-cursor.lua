return {
  "mg979/vim-visual-multi",
  branch = "master",
  keys = {
    { "<A-n>", mode = { "n", "x" }, desc = "VM: Find next occurrence" },
    { "<A-d>", mode = { "n", "x" }, desc = "VM: Select all occurrences" },
    { "<C-Up>", mode = { "n" }, desc = "VM: Add cursor up" },
    { "<C-Down>", mode = { "n" }, desc = "VM: Add cursor down" },
  },
  init = function()
    -- Disable default mappings to avoid clutter
    vim.g.VM_default_mappings = 0

    -- Custom mappings
    vim.g.VM_maps = {
      ["Find Under"] = "<A-n>", -- Select word under cursor, repeat for next occurrence
      -- ["Find Subword Under"] = "<A-n>", -- Subword selection (camelCase parts) - revisit later
      ["Select All"] = "<A-d>", -- Select all occurrences of word under cursor
      ["Visual Add"] = "<A-n>", -- In visual mode: find next occurrence of selected text
      ["Visual All"] = "<A-d>", -- In visual mode: select all occurrences of selected text
      ["Find Next"] = "<A-n>", -- After entering VM mode: find next occurrence
      ["Find Prev"] = "<A-p>", -- After entering VM mode: find previous occurrence
      ["Add Cursor Down"] = "<C-Down>", -- Add cursor below
      ["Add Cursor Up"] = "<C-Up>", -- Add cursor above
      ["Skip Region"] = "<C-x>", -- Skip current match and go to next
      ["Remove Region"] = "<C-p>", -- Remove current cursor/selection
      ["Start Regex Search"] = "\\/", -- Start regex search for multi-cursor
      ["Visual Regex"] = "\\/", -- Visual mode regex
      ["Undo"] = "u",
      ["Redo"] = "<C-r>",
    }

    -- Use your theme colors
    vim.g.VM_theme = "auto"

    -- Show number of matches in command line
    vim.g.VM_show_warnings = 1
  end,
}
