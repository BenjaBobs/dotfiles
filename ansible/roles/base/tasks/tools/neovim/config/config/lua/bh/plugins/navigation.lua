return {
  "folke/flash.nvim",
  tag = "v2.1.0",
  commit = "ec0bf2842189f65f60fd40bf3557cac1029cc932",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    label = {
      rainbow = {
        enabled = true,
      },
    },
    modes = {
      char = {
        enabled = false,
      },
    },
  },
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump({ mode = "smart-case" })
      end,
      desc = "Flash",
    },
    {
      "S",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter",
    },
  },
}
