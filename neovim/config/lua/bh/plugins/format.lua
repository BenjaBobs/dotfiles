return {
  "stevearc/conform.nvim",
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters_by_ft = {
        lua = { "stylua" },
      },
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true })
    end, { desc = "[F]ormat" })
  end,
}
