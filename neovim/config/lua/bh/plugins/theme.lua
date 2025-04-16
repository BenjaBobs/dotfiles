return {
  {
    -- the colorscheme should be available when starting Neovim
    "catppuccin/nvim",
    name = "catppuccin",
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
    tag = "v0.9.1",
    submodules = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function() end,
  },
}
