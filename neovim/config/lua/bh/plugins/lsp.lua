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
      -- http / rest client kulala
      kulala_ls = {},
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

    -- Clean neovim ShaDa temporary files (Windows only)
    if vim.fn.has("win32") == 1 then
      local function clean_shada_tmp_files()
        local shada_dir = vim.fn.stdpath("data") .. "/shada"
        local full_cmd = 'del /q "' .. shada_dir:gsub("/", "\\") .. '\\main.shada.tmp.*"'
        vim.fn.system(full_cmd)
      end

      -- Manual cleanup keymap
      vim.keymap.set("n", "<leader>rc", function()
        clean_shada_tmp_files()
        print("ShaDa temporary files cleaned")
      end, { desc = "[R]un [C]lean neovim ShaDa files", silent = true })

      -- Auto cleanup on exit
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = clean_shada_tmp_files,
        desc = "Clean ShaDa temporary files on exit",
      })
    end
  end,
}
