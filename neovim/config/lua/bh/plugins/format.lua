return {
  "stevearc/conform.nvim",
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        javascript = { "biome", "eslint_d", "prettier" },
        javascriptreact = { "biome", "eslint_d", "prettier" },
        typescript = { "biome", "eslint_d", "prettier" },
        typescriptreact = { "biome", "eslint_d", "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        cs = { "csharpier" },
        lua = { "stylua" },
        http = { "kulala_fmt" },
        rest = { "kulala_fmt" }
      },

      format_on_save = {
        enabled = true,      -- Globally enable format on save.
        timeout = 2000,      -- Timeout (in ms) for formatting.
        lsp_fallback = true, -- If no formatter is available for the filetype, fall back to LSP formatting.
        async = false,
      },
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true, lsp_fallback = true })
    end, { desc = "[F]ormat" })

    vim.keymap.set("n", "<leader>bw", ":noau w", { desc = "[W]rite without formatting" })
  end,
}
