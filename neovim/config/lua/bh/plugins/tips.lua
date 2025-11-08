return {
  "saxon1964/neovim-tips",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "MeanderingProgrammer/render-markdown.nvim", -- You already have this
  },
  lazy = false, -- Load on startup for daily tip
  opts = {
    daily_tip = 0, -- Show a random tip once per day (0 = off, 1 = once daily, 2 = every startup)
    user_file = vim.fn.stdpath("config") .. "/my-neovim-tips.md", -- Your custom tips
    user_tip_prefix = "My Tip", -- Prefix for your custom tips
    warn_on_conflicts = true, -- Warn if tip titles conflict
    bookmark_symbol = "★", -- Symbol for bookmarked tips
  },
  keys = {
    {
      "<leader>ft",
      "<cmd>NeovimTips<cr>",
      desc = "[F]ind [T]ips",
    },
    {
      "<leader>fT",
      "<cmd>NeovimTipsRandom<cr>",
      desc = "[F]ind Random [T]ip",
    },
  },
}
