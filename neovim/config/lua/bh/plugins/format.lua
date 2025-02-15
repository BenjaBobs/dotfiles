return {
  "stevearc/conform.nvim",
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        javascript = { "eslint_d", "prettier", "biome" },
        javascriptreact = { "eslint_d", "prettier", "biome" },
        typescript = { "eslint_d", "prettier", "biome" },
        typescriptreact = { "eslint_d", "prettier", "biome" },
        css = { "prettier", "biome" },
        scss = { "prettier", "biome" },
        html = { "prettier", "biome" },
        json = { "prettier", "biome" },
        yaml = { "prettier", "biome" },
        markdown = { "prettier", "biome" },
        cs = { "csharpier" },
        lua = { "stylua" },
      },

      format_on_save = {
        enabled = true, -- Globally enable format on save.
        timeout = 1000, -- Timeout (in ms) for formatting.
        lsp_fallback = true, -- If no formatter is available for the filetype, fall back to LSP formatting.
        async = false,
      },
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true })
    end, { desc = "[F]ormat" })
  end,
}
