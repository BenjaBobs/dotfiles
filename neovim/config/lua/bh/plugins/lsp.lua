return {
  "neovim/nvim-lspconfig",
  dependencies = {
    { -- Neovim types and globals
      "folke/lazydev.nvim",
      ft = "lua",
      opts = {
        library = {
          { path = "${3rd}/luv/library", words = { "vim%.uv" } }
        }
      }
    },
    { -- Auto-complete
      "saghen/blink.cmp",
      dependencies = "rafamadriz/friendly-snippets",
      version = "v0.*",
      opts = {
        keymap = { preset = "default" },
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
        },
        signature = { enabled = true },
      }
    }
  },
  config = function()
    local lspCfg = require("lspconfig")
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    lspCfg.lua_ls.setup { capabilities = capabilities }
    lspCfg.zls.setup { capabilities = capabilities }
    lspCfg.ts_ls.setup { capabilities = capabilities }

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then return end

        -- Format on save
        if client.supports_method("textDocument/formatting") then
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = args.buf,
            callback = function()
              vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
            end
          })
        end
      end
    })
  end,
}
