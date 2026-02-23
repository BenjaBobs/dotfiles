return {
  { -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",

    -- Treesitter maintains its own parsers; this keeps them up to date
    build = ":TSUpdate",

    -- NOTE:
    -- On the *main* branch of nvim-treesitter, we must NOT use `main = ...`
    -- Lazy.nvim would try to `require()` the module too early,
    -- before treesitter has finished setting up its runtime paths.
    --
    -- Because of this, we use an explicit `config` function instead of
    -- `main + opts`.
    config = function()
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
      require("nvim-treesitter").setup({

        -- A list of parser names, or "all"
        ensure_installed = {
          "bash",
          "c",
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
          "typescript",
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
