return {
  "neovim/nvim-lspconfig",
  tag = "v2.9.0",
  commit = "f6738ef65dabade340b473d4ff2a1ad3352c10e7",
  dependencies = {
    { -- Neovim types and globals
      "folke/lazydev.nvim",
      tag = "v1.10.0",
      commit = "01bc2aacd51cf9021eb19d048e70ce3dd09f7f93",
      ft = "lua",
      opts = {
        library = {
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
    { -- Auto-complete
      "saghen/blink.cmp",
      tag = "v1.10.2",
      commit = "78336bc89ee5365633bcf754d93df01678b5c08f",
      dependencies = {
        {
          "rafamadriz/friendly-snippets",
          commit = "6cd7280adead7f586db6fccbd15d2cac7e2188b9",
        },
      },
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
    {
      "mason-org/mason.nvim",
      tag = "v2.3.0",
      commit = "bb639d4bf385a4d89f478b83af4d770be05ab7eb",
    },
    {
      "mason-org/mason-lspconfig.nvim",
      tag = "v2.2.0",
      commit = "0c2823e0418f3d9230ff8b201c976e84de1cb401",
    },
  },
  config = function()
    -- See `:help lspconfig-all` or https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            telemetry = { enable = false },
            -- NOTE: toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            diagnostics = { disable = { "missing-fields" } },
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

    require("mason").setup({
      registries = {
        "github:mason-org/mason-registry",
      },
    })
    require("mason-lspconfig").setup({
      ensure_installed = ensure_installed,
      automatic_enable = false,
    })

    for server, settings in pairs(servers) do
      vim.lsp.config(server, settings)
      vim.lsp.enable(server)
    end

    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    local roslyn_language_server = dotnet_tools .. "/roslyn-language-server"

    vim.lsp.config("roslyn_ls", {
      cmd = {
        vim.fn.executable(roslyn_language_server) == 1 and roslyn_language_server or "roslyn-language-server",
        "--stdio",
      },
      settings = {
        ["csharp|background_analysis"] = {
          dotnet_analyzer_diagnostics_scope = "openFiles",
          dotnet_compiler_diagnostics_scope = "openFiles",
        },
      },
    })
    vim.lsp.enable("roslyn_ls")

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end

        local mapN = function(keys, action, description)
          vim.keymap.set("n", keys, action, { buffer = args.buf, silent = true, noremap = true, desc = description })
        end

        mapN("<leader>cr", vim.lsp.buf.rename, "[R]ename Symbol")
        mapN("<leader>ca", vim.lsp.buf.code_action, "[A]ctions")

        mapN("gd", function()
          Snacks.picker.lsp_definitions()
        end, "Goto [d]efinition")
        mapN("gD", function()
          Snacks.picker.lsp_declarations()
        end, "Goto [D]eclaration")
        mapN("gr", function()
          Snacks.picker.lsp_references()
        end, "Goto [r]eferences") -- nowait = true
        mapN("gI", function()
          Snacks.picker.lsp_implementations()
        end, "Goto [I]mplementation")
        mapN("gy", function()
          Snacks.picker.lsp_type_definitions()
        end, "Goto T[y]pe Definition")
        mapN("<leader>fs", function()
          Snacks.picker.lsp_symbols()
        end, "[F]ind LSP [S]ymbols")
        mapN("<leader>fS", function()
          Snacks.picker.lsp_workspace_symbols()
        end, "[F]ind LSP Workspace [S]ymbols")
      end,
    })
  end,
}
