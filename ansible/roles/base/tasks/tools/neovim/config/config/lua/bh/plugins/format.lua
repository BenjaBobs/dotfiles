return {
  "stevearc/conform.nvim",
  tag = "v9.1.0",
  commit = "3543d000dafbc41cc7761d860cfdb24e82154f75",
  config = function()
    local conform = require("conform")
    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    local csharpier = dotnet_tools .. "/csharpier"

    conform.setup({
      formatters = vim.fn.executable(csharpier) == 1 and {
        csharpier = {
          command = csharpier,
        },
      } or {},
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
        http = { "kulala_fmt" },
        rest = { "kulala_fmt" },
      },

      format_on_save = {
        enabled = true, -- Globally enable format on save.
        timeout = 2000, -- Timeout (in ms) for formatting.
        lsp_format = "fallback", -- If no formatter is available for the filetype, fall back to LSP formatting.
        async = false,
      },
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true, lsp_format = "fallback" })
    end, { desc = "[F]ormat" })

    vim.keymap.set("n", "<leader>bw", ":noau w", { desc = "[W]rite without formatting" })
  end,
}
