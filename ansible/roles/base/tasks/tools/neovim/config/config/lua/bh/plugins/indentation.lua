return {
  "shellRaining/hlchunk.nvim",
  tag = "v1.3.0",
  commit = "d5e45809ed93991ade8e10e4f706cd7699b17430",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("hlchunk").setup({
      chunk = {
        enable = true,
        delay = 50,
        duration = 50,
        chars = {
          horizontal_line = "─",
          vertical_line = "│",
          left_top = "╭",
          left_bottom = "╰",
          right_arrow = "─",
        },
      },
      indent = {
        enable = true,
      },
      line_num = {
        enable = true,
      },
    })
  end,
}
