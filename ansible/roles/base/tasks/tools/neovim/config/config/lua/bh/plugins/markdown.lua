return {
  "MeanderingProgrammer/render-markdown.nvim",
  tag = "v8.12.0",
  commit = "e3c18ddd27a853f85a6f513a864cf4f2982b9f26",
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter",
      -- Release tags lag the current main branch and use the old setup API.
      commit = "4916d6592ede8c07973490d9322f187e07dfefac",
    },
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {},
}
