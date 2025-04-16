return {
  "neovim/nvim-lspconfig",
  dependencies = {
    { -- Neovim types and globals
      "folke/lazydev.nvim",
      ft = "lua",
      opts = {
        library = {
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
    { -- Auto-complete
      "saghen/blink.cmp",
      dependencies = "rafamadriz/friendly-snippets",
      version = "v1.*",
      opts = {
        keymap = {
          preset = "super-tab",
          ["<A-.>"] = { "show", "show_documentation", "hide_documentation" },
          ["<C-.>"] = { "show", "show_documentation", "hide_documentation" },
        },
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
        },
        signature = { enabled = true },
        sources = {
          providers = {
            markdown = {
              name = "RenderMarkdown",
              module = "render-markdown.integ.blink",
              fallbacks = { "lsp" },
            },
          },
        },
        completion = {
          list = {
            selection = {
              preselect = true,
              auto_insert = false,
            },
          },
          documentation = {
            auto_show = true,
          },
          menu = {
            draw = {
              columns = {
                { "kind_icon" },
                { "label", gap = 1 },
                { "source_name", gap = 1 },
              },
            },
          },
        },
      },
    },
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    -- See `:help lspconfig-all` or https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            telemetry = { enable = false },
            -- NOTE: toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            -- diagnostics = { disable = { "missing-fields" } },
            hint = { enable = true },
          },
        },
      },
      -- Typescript/javascript: https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
      vtsls = {
        settings = {
          ["js/ts"] = { implicitProjectConfig = { checkJs = true } },
          complete_function_calls = true,
          vtsls = {
            enableMoveToFileCodeAction = true,
            autoUseWorkspaceTsdk = true,
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
              },
            },
          },
          javascript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              parameterNames = { enabled = "literals" },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = false },
            },
            preferences = {
              importModuleSpecifierPreference = "non-relative",
            },
          },
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              parameterNames = { enabled = "literals" },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = false },
            },
            preferences = {
              importModuleSpecifierPreference = "non-relative",
            },
          },
        },
      },
      -- Css
      cssls = {},
    }

    local ensure_installed = vim.tbl_keys(servers or {})

    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = ensure_installed,
    })

    for server, settings in pairs(servers) do
      vim.lsp.config(server, settings)
      vim.lsp.enable(server)
    end

    -- local lspCfg = require("lspconfig")
    -- local capabilities = require("blink.cmp").get_lsp_capabilities()
    --
    -- lspCfg.lua_ls.setup({ capabilities = capabilities })
    -- lspCfg.zls.setup({ capabilities = capabilities })
    -- lspCfg.ts_ls.setup({
    --   capabilities = capabilities,
    --   init_options = {
    --     preferences = {
    --       importModuleSpecifierPreference = "non-relative", -- this is the magic
    --       importModuleSpecifierEnding = "auto",
    --       includePackageJsonAutoImports = "on",
    --     },
    --   },
    --   settings = {
    --     typescript = {
    --       preferences = {
    --         importModuleSpecifierPreference = "non-relative",
    --       },
    --     },
    --     javascript = {
    --       preferences = {
    --         importModuleSpecifierPreference = "non-relative",
    --       },
    --     },
    --   },
    -- })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end

        local mapN = function(keys, action, description)
          vim.keymap.set("n", keys, action, { buffer = args.buf, silent = true, noremap = true, desc = description })
        end

        local telescope = require("telescope.builtin")

        -- local lspLines = require("lsp_lines")
        -- mapN("<leader>cl", lspLines.toggle, "Toggle multi[L]ine errors")

        mapN("gd", vim.lsp.buf.definition, "Go to [D]efinition")
        mapN("gD", vim.lsp.buf.declaration, "Go to Declaration")
        mapN("gi", function()
          telescope.lsp_implementations()
        end, "Go to [I]mplementation")
        mapN("gr", function()
          telescope.lsp_references()
        end, "Go to [R]eferences")
        mapN("gy", vim.lsp.buf.type_definition, "Go to T[y]pe Definition")
        mapN("K", vim.lsp.buf.hover, "Hover Documentation")
        mapN("<leader>cr", vim.lsp.buf.rename, "[R]ename Symbol")
        mapN("<leader>ca", vim.lsp.buf.code_action, "[A]ctions")
        mapN("<C-.>", vim.lsp.buf.code_action, "[A]ctions")
        mapN("<leader>fs", function()
          telescope.lsp_document_symbols()
        end, "[S]ymbols (document)")
        mapN("<leader>fS", function()
          telescope.lsp_workspace_symbols()
        end, "[S]ymbols (workspace)")
      end,
    })
  end,
}
