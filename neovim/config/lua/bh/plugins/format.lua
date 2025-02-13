return {
  "stevearc/conform.nvim",
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        javascript = { "eslint_d", "prettier" },
        javascriptreact = { "eslint_d","prettier" },
        typescript = { "eslint_d", "prettier" },
        typescriptreact = { "eslint_d","prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        cs = { "csharpier" },
        lua = { "stylua" },
      },

      -- format_on_save = {
      --   enabled = true,      -- Globally enable format on save.
      --   timeout = 1000,      -- Timeout (in ms) for formatting.
      --   lsp_fallback = true, -- If no formatter is available for the filetype, fall back to LSP formatting.
      --   async = true,
      -- },
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true })
    end, { desc = "[F]ormat" })
  end,
}
