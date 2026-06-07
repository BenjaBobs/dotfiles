local float_win = {
  position = "float",
  width = 0.9,
  height = 0.9,
  border = "rounded",
}

return {
  "folke/snacks.nvim",
  tag = "v2.31.0",
  commit = "e6fd58c82f2f3fcddd3fe81703d47d6d48fc7b9f",
  keys = {
    {
      "<leader>rt",
      function()
        Snacks.terminal.toggle(nil, { win = float_win })
      end,
      desc = "[R]un [T]erminal",
    },
    {
      "<leader>rg",
      function()
        Snacks.terminal("gitui", { win = float_win })
      end,
      desc = "[R]un [G]itui",
    },
    {
      "<leader>rn",
      function()
        Snacks.picker.commands()
      end,
      desc = "[R]un [N]eovim Command",
    },
  },
}
