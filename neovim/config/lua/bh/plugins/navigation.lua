return {
  "folke/flash.nvim",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    label = {
      rainbow = {
        enabled = true,
      }
    },
    modes = {
      char = {
        enabled = false,
      },
    },
  },
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump({ mode = "smart-case" }) end, desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,                  desc = "Flash Treesitter" },
  },
}
