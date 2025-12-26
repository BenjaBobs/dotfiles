return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
    },
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")

      local function map(mode, lhs, rhs, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, lhs, rhs, opts)
      end

      -- Navigation
      map("n", "<leader>gn", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gitsigns.nav_hunk("next")
        end
      end, { desc = "[N]ext hunk" })

      map("n", "<leader>gp", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gitsigns.nav_hunk("prev")
        end
      end, { desc = "[P]revious hunk" })

      -- Actions
      map("n", "<leader>ga", gitsigns.stage_hunk, { desc = "St[a]ge hunk" })
      map("n", "<leader>gr", gitsigns.reset_hunk, { desc = "[R]eset hunk" })
      map("v", "<leader>ga", function()
        gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "St[a]ge hunk" })
      map("v", "<leader>gr", function()
        gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "[R]eset hunk" })
      map("n", "<leader>gA", gitsigns.stage_buffer, { desc = "St[A]ge buffer" })
      map("n", "<leader>gu", gitsigns.undo_stage_hunk, { desc = "[U]ndo stage hunk" })
      map("n", "<leader>gR", gitsigns.reset_buffer, { desc = "[R]eset buffer" })
      map("n", "<leader>gd", gitsigns.preview_hunk, { desc = "[D]iff/preview hunk" })
      map("n", "<leader>gl", function()
        gitsigns.blame_line({ full = true })
      end, { desc = "B[l]ame line" })
      map("n", "<leader>gD", gitsigns.diffthis, { desc = "[D]iff this" })

      -- Text object
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
    end,
  },
}
