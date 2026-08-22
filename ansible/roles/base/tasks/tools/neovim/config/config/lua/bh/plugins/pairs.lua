return {
  -- Autopairs. Typing `(` inserts `()` with the cursor between them, and typing
  -- the closing character steps over the existing one instead of inserting a
  -- duplicate -- so `foo("bar")` is typed left to right with no cursor motion.
  -- Also maps <BS> (deletes both halves inside a pair) and <CR> (opens a blank
  -- line between them). blink's `super-tab` preset does not map <CR>, so there
  -- is no conflict there.
  {
    "nvim-mini/mini.pairs",
    tag = "v0.18.0",
    commit = "4a014143fcb4e9df26198ccb3ecff3b9e77a048c",
    event = "InsertEnter",
    opts = {},
    config = function(_, opts)
      require("mini.pairs").setup(opts)

      local matching_pair = {
        ["("] = ")",
        ["["] = "]",
        ["{"] = "}",
      }

      -- MiniPairs.cr() recognizes only adjacent pairs. Treat whitespace-only
      -- pair contents the same way, so Enter inside `{ }`, `[  ]`, or `( )`
      -- removes that padding and opens a properly indented blank line. This is
      -- deliberately filetype-agnostic: the opening delimiter stays where it
      -- was typed, while the active indentexpr decides the inner indentation.
      local function whitespace_pair_cr()
        if vim.g.minipairs_disable == true or vim.b.minipairs_disable == true then return end

        local col = vim.api.nvim_win_get_cursor(0)[2]
        local line = vim.api.nvim_get_current_line()
        local before, after = line:sub(1, col), line:sub(col + 1)
        local open, left_padding = before:match("([%(%[%{])(%s*)$")
        local right_padding, close = after:match("^(%s*)([%)%]%}])")
        if not open or matching_pair[open] ~= close then return end
        if #left_padding == 0 and #right_padding == 0 then return end

        return string.rep(vim.keycode("<BS>"), #left_padding)
          .. string.rep(vim.keycode("<Del>"), #right_padding)
          .. vim.keycode("<CR><C-o>O")
      end

      vim.keymap.set("i", "<CR>", function()
        return whitespace_pair_cr() or MiniPairs.cr()
      end, {
        expr = true,
        replace_keycodes = false,
        desc = "MiniPairs <CR> with whitespace tolerance",
      })
    end,
  },

  -- Surround existing text: `gsaiw"` quotes a word, `gsr"'` swaps quote style,
  -- No `gs*` surface: every upstream keymap is disabled with '' (see
  -- :h MiniSurround.config). What's exposed instead is pre-baked combinations --
  -- the visual-mode one-key wrappers, plus <leader>st to strip an HTML tag. The
  -- operations they call are bound to unreachable <Plug> lhs's.
  --
  -- Not bound: replace (upstream `sr`, including tag renaming) and find/highlight.
  -- Reach those via :lua MiniSurround.replace() or ask for keys.
  {
    "nvim-mini/mini.surround",
    tag = "v0.18.0",
    commit = "580e4cb98c5900d9fe743865fb5a5b2178b4ab18",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "<Plug>(bh-surround-add)",
        delete = "<Plug>(bh-surround-delete)",
        find = "",
        find_left = "",
        highlight = "",
        replace = "",
        suffix_last = "",
        suffix_next = "",
      },
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)

      -- Strip the enclosing HTML/XML tag pair, keeping its contents. Normal mode,
      -- because the target is the pair around the cursor -- there is nothing to
      -- select. The `t` identifier is baked in, so there's no prompt.
      vim.keymap.set("n", "<leader>st", function()
        local keys = "<Plug>(bh-surround-delete)t"
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
      end, { desc = "[S]urround: delete [T]ag" })

      -- One-key wrapping from visual mode. Select first -- v, viw, V, or +/- to
      -- grow/shrink a treesitter node -- so you can see exactly what's targeted,
      -- then press one key. Replaces the hand-rolled ( [ { maps that used to live
      -- in which-key.lua; those clobbered register `t` and mishandled linewise
      -- selections.
      --
      -- The table value is mini.surround's *output* identifier. Closing brackets
      -- are deliberate: they add no padding, so you get (sel) not ( sel ).
      --
      -- Costs, since these shadow visual-mode defaults: `"` no longer starts a
      -- register prefix, `'` no longer jumps to a mark, and ( { are no longer
      -- sentence/paragraph motions.
      local wrappers = {
        ["("] = ")",
        ["["] = "]",
        ["{"] = "}",
        ['"'] = '"',
        ["'"] = "'",
        ["`"] = "`",
      }
      for lhs, output in pairs(wrappers) do
        vim.keymap.set("x", lhs, function()
          local keys = "<Plug>(bh-surround-add)" .. output
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
          -- Reselect including the new delimiters, so another wrap can follow
          -- immediately. `normal!` so this isn't caught by these same mappings.
          pcall(vim.cmd, "normal! va" .. lhs)
        end, { desc = "Surround selection with " .. lhs .. output })
      end
    end,
  },
}
