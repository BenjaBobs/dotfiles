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
        keymap = {
          preset = "super-tab",
          ['<A-.>'] = { 'show', 'show_documentation', 'hide_documentation' },
          ['<C-.>'] = { 'show', 'show_documentation', 'hide_documentation' },
        },
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
        },
        signature = { enabled = true },
        completion = {
          list = {
            selection = {
              preselect = false,
              auto_insert = false,
            }
          }
        },
      },
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

        local mapN = function(keys, action, description)
          vim.keymap.set('n', keys, action, { buffer = args.buf, silent = true, noremap = true, desc = description })
        end

        mapN('gd', vim.lsp.buf.definition, 'Go to Definition')
        mapN('gD', vim.lsp.buf.declaration, 'Go to Declaration')
        mapN('gi', vim.lsp.buf.implementation, 'Go to Implementation')
        mapN('gr', vim.lsp.buf.references, 'Go to References')
        mapN('gy', vim.lsp.buf.type_definition, 'Go to Type Definition')
        mapN('K', vim.lsp.buf.hover, 'Hover Documentation')
        mapN('<leader>cr', vim.lsp.buf.rename, '[R]ename Symbol')
        mapN('<leader>ca', vim.lsp.buf.code_action, '[A]ctions')
      end
    })
  end,
}
