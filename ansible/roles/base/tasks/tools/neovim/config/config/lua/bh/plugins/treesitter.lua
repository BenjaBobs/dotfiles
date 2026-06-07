return {
  { -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    -- Release tags lag the current main branch and use the old setup API.
    commit = "4916d6592ede8c07973490d9322f187e07dfefac",

    -- Treesitter maintains its own parsers; this keeps them up to date
    build = ":TSUpdate",

    config = function()
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
      require("nvim-treesitter").setup({

        -- A list of parser names, or "all"
        ensure_installed = {
          "bash",
          "c",
          "c_sharp",
          "diff",
          "html",
          "lua",
          "luadoc",
          "markdown",
          "markdown_inline",
          "query",
          "vim",
          "vimdoc",
          "javascript",
          "jsx",
          "typescript",
          "tsx",
          "zig",
        },

        -- Install parsers synchronously (only applied to `ensure_installed`)
        -- Set to false if you don’t want blocking installs on startup
        auto_install = true,

        highlight = {
          enable = true,

          -- Some languages depend on Vim’s regex highlighting system
          -- (such as Ruby) for indent rules.
          --
          -- If you are experiencing weird indenting issues, add the language
          -- to this list and disable treesitter-based indenting for it.
          additional_vim_regex_highlighting = { "ruby" },
        },

        -- Indentation based on treesitter for the languages that support it
        indent = {
          enable = true,
          disable = { "ruby" },
        },
      })
    end,

    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
