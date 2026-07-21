return {
  { -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    -- Release tags lag the current main branch and use the old setup API.
    commit = "4916d6592ede8c07973490d9322f187e07dfefac",

    -- Treesitter maintains its own parsers; this keeps them up to date
    build = ":TSUpdate",

    config = function()
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
      --
      -- This commit tracks nvim-treesitter's `main` branch, which removed the
      -- old module system: `ensure_installed`, `auto_install`, `highlight`, and
      -- `indent` are no longer `setup()` options (they are silently ignored).
      -- Parsers are installed with `install()` and features are enabled
      -- per-buffer in a FileType autocommand. See `:help nvim-treesitter`.
      local ts = require("nvim-treesitter")

      -- Parsers to install. `install()` is asynchronous and a no-op for parsers
      -- that are already present, so it is cheap to run on every startup. (The
      -- first run after adding a parser compiles it, which needs a C compiler
      -- and network access.)
      ts.install({
        "bash",
        "c",
        "c_sharp",
        "diff",
        "html",
        "luadoc",
        "markdown",
        "markdown_inline",
        "query",
        "vim",
        "vimdoc",
        "javascript",
        "typescript",
        "tsx",
        "zig",
      })

      -- Enable Treesitter highlighting (Neovim core) and indentation
      -- (nvim-treesitter) per buffer. `get_lang` maps the filetype to a parser
      -- language (e.g. `cs` -> `c_sharp`); `vim.treesitter.start` errors when no
      -- parser is installed, so the pcall lets unsupported filetypes fall back
      -- to Vim's built-in syntax highlighting.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if lang and pcall(vim.treesitter.start, ev.buf, lang) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Neovim 0.12 ships a Lua parser that matches its runtime queries.
      -- Prefer it over nvim-treesitter's parser when both are on runtimepath.
      local lua_parser = vim.iter(vim.api.nvim_get_runtime_file("parser/lua.so", true)):find(function(path)
        return not path:find("/nvim%-treesitter/")
      end)
      assert(lua_parser, "Neovim's bundled Lua parser was not found")
      vim.treesitter.language.add("lua", { path = lua_parser })
    end,

    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
