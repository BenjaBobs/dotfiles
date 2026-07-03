return {
  "stevearc/conform.nvim",
  tag = "v9.1.0",
  commit = "3543d000dafbc41cc7761d860cfdb24e82154f75",
  config = function()
    local conform = require("conform")
    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    local csharpier = dotnet_tools .. "/csharpier"

    local formatters = {
      -- Requires the `kulala-fmt` CLI on PATH (npm/bun i -g
      -- @mistweaverco/kulala-fmt). NOTE: the formatter name uses a hyphen —
      -- `kulala_fmt` (underscore) is not a valid formatter.
      --
      -- We drive it through its stdin interface (`fix --stdin`) rather than
      -- conform's builtin `format $FILENAME`: the current v4 CLI hangs on the
      -- file-argument form (times out), but reads stdin and writes the
      -- formatted result to stdout cleanly.
      ["kulala-fmt"] = {
        command = "kulala-fmt",
        args = { "fix", "--stdin" },
        stdin = true,
      },
    }

    if vim.fn.executable(csharpier) == 1 then
      formatters.csharpier = {
        command = csharpier,
        args = { "format", "--stdin-path", "$FILENAME" },
        stdin = true,
      }
    end

    conform.setup({
      formatters = formatters,
      formatters_by_ft = {
        javascript = { "biome" },
        javascriptreact = { "biome" },
        typescript = { "biome" },
        typescriptreact = { "biome" },
        css = { "biome" },
        scss = { "biome" },
        html = { "biome" },
        json = { "biome" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        cs = { "csharpier" },
        lua = { "stylua" },
        http = { "kulala-fmt" },
        rest = { "kulala-fmt" },
      },
    
      format_on_save = function(bufnr)
        if vim.tbl_contains({ "http", "rest" }, vim.bo[bufnr].filetype) then
          -- Format with kulala-fmt only. Never fall back to the kulala
          -- LSP: its formatting inserts a leading `###` that demotes document
          -- variables into the first request block and breaks them.
          return { timeout_ms = 3000, lsp_format = "never" }
        end

        return {
          timeout_ms = 2000, -- Timeout (in ms) for formatting.
          lsp_format = "fallback", -- If no formatter is available for the filetype, fall back to LSP formatting.
          async = false,
        }
      end,
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true, lsp_format = "fallback" })
    end, { desc = "[F]ormat" })

    vim.keymap.set("n", "<leader>bw", ":noau w", { desc = "[W]rite without formatting" })
  end,
}
