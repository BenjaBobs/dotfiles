return {
  "saxon1964/neovim-tips",
  tag = "v0.8.4",
  commit = "1339a0da1ff59fab8cfc07661ef92aa8c7d07f79",
  dependencies = {
    {
      "MunifTanjim/nui.nvim",
      tag = "0.4.0",
      commit = "f535005e6ad1016383f24e39559833759453564e",
    },
    -- Version and rendering options are configured in markdown.lua.
    "MeanderingProgrammer/render-markdown.nvim",
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
