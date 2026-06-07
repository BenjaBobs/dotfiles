return {
  {
    -- the colorscheme should be available when starting Neovim
    "catppuccin/nvim",
    name = "catppuccin",
    tag = "v2.0.0",
    commit = "605b4603797de970e9f3a4238c199c850da03186",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        integrations = {
          blink_cmp = true,
          cmp = true,
          gitsigns = true,
          treesitter = true,
          notify = true,
          fidget = true,
          flash = true,
          which_key = true,
          rainbow_delimiters = true,
        },
      })

      -- load the colorscheme here
      vim.cmd([[colorscheme catppuccin]])
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    tag = "v0.12.0",
    commit = "b81d594e82b6ca1530797bdcfd16a1219250a2d8",
    submodules = false,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        -- Release tags lag the current main branch and use the old setup API.
        commit = "4916d6592ede8c07973490d9322f187e07dfefac",
      },
    },
    config = function() end,
  },
}
