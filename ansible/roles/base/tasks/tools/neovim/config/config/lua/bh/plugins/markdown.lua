return {
  "MeanderingProgrammer/render-markdown.nvim",
  tag = "v8.14.0",
  commit = "640a3ec6d538bad17c328be373c7cad0293d9589",
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
