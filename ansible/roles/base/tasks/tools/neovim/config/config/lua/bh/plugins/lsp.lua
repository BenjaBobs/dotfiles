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
        signature = {
          enabled = true,
          window = { border = "rounded" },
        },
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
      zls = {},
      -- Markdown: document/workspace symbols (heading outline), link
      -- navigation (goto def/references) and link completion.
      marksman = {},
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

    -- ZLS republishes diagnostics frequently while editing, which causes
    -- statusline and floating-window redraws even though diagnostic rendering
    -- itself is disabled in insert mode. Keep only the latest update and apply
    -- it when insert mode ends.
    local publish_diagnostics = vim.lsp.handlers["textDocument/publishDiagnostics"]
    local pending_zls_diagnostics = {}

    vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local bufnr = result and result.uri and vim.uri_to_bufnr(result.uri)
      local mode = vim.api.nvim_get_mode().mode

      if client and client.name == "zls" and bufnr == vim.api.nvim_get_current_buf() and mode:sub(1, 1) == "i" then
        pending_zls_diagnostics[bufnr] = {
          err = err,
          result = result,
          ctx = ctx,
          config = config,
        }
        return
      end

      publish_diagnostics(err, result, ctx, config)
    end

    vim.api.nvim_create_autocmd("InsertLeave", {
      callback = function(args)
        local pending = pending_zls_diagnostics[args.buf]
        if not pending then
          return
        end

        pending_zls_diagnostics[args.buf] = nil
        publish_diagnostics(pending.err, pending.result, pending.ctx, pending.config)
      end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
      callback = function(args)
        pending_zls_diagnostics[args.buf] = nil
      end,
    })

    for server, settings in pairs(servers) do
      vim.lsp.config(server, settings)
      vim.lsp.enable(server)
    end

    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    local roslyn_language_server = dotnet_tools .. "/roslyn-language-server"

    -- Roslyn flattens XML doc comments into markdown that nothing downstream
    -- undoes, so hovers show the raw markup:
    --
    --   * Punctuation in prose is markdown-escaped (`through\.`, `mid\-2025`).
    --     Neither `vim.lsp.util._normalize_markdown` nor render-markdown.nvim
    --     process backslash escapes, so they stay literal.
    --   * Whitespace around `<see cref="..."/>` is emitted as `&nbsp;`. Nvim's
    --     markdown_inline query conceals that to a space, but only at
    --     'conceallevel' 2 (what `open_floating_preview` sets);
    --     render-markdown.nvim raises rendered buffers to 3, where conceal
    --     replacements are dropped entirely and words run together.
    --
    -- Roslyn does have a lossless alternative -- advertising
    -- `_vs_supportsVisualStudioExtensions` makes hovers carry `_vs_rawContent`
    -- with every run classified, and `bh.roslyn-hover` renders it. It is not
    -- wired up because that capability also switches the semantic tokens legend
    -- to VS `ClassificationTypeNames`, 72 of which contain spaces and so cannot
    -- form `@lsp.type.<name>.<ft>` highlight groups: 256 E5248 errors on one
    -- small file, and C# semantic highlighting broken. Adopting it means
    -- remapping all 98 token names first.
    local html_entities = {
      ["&nbsp;"] = " ",
      ["&amp;"] = "&",
      ["&lt;"] = "<",
      ["&gt;"] = ">",
      ["&quot;"] = '"',
      ["&apos;"] = "'",
    }

    -- `<b>`, `<i>` and `<c>` reach us as real markdown (`**x**`, `_x_`, `` `x` ``)
    -- and render on their own. `<see cref>`, `<see langword>` and `<paramref>`
    -- arrive as bare text, and the only thing marking them is the `&nbsp;` that
    -- Roslyn substitutes for whitespace touching an inline element. That marker
    -- is not exclusive to elements -- a real payload also contains
    -- `&nbsp;here,&nbsp;` and `&nbsp;and&nbsp;` -- so exact detection is not
    -- possible here. Matching segments that look like C# identifiers picks up
    -- crefs by naming convention and rejects prose. A miss is only cosmetic: a
    -- capitalised prose word shown as code, or a lowercase `<paramref>` left
    -- plain.
    local langwords = {
      ["null"] = true,
      ["true"] = true,
      ["false"] = true,
      ["void"] = true,
      ["static"] = true,
      ["async"] = true,
      ["await"] = true,
      ["abstract"] = true,
      ["virtual"] = true,
      ["override"] = true,
      ["sealed"] = true,
      ["readonly"] = true,
    }

    -- Deliberately requires two characters and an uppercase start, so single
    -- letters and lowercase connectives ("and", "here,") stay prose.
    local function looks_like_symbol(s)
      return langwords[s] == true or s:match("^%u[%w_.]*[%w_]$") ~= nil
    end

    -- Mark qualified names (`NavItem.DutyCode`, `NavWineTax.Duty(System.Decimal)`)
    -- anywhere in a stretch of text. Roslyn emits `&nbsp;` only for *whitespace*
    -- touching an element, so a cref hard against punctuation -- "as is
    -- NavItem.DutyCode.", "(NavItem.BaseUnitofMeasure)" -- has no marker at all
    -- and can only be found by shape. The required dot is what keeps this off
    -- prose: "There is no duty amount" and "in the ERP. A caller" both start
    -- capitalised, but neither has a dot bound tightly to its word.
    local function mark_qualified(text)
      local pieces, pos = {}, 1
      while true do
        local first, last = text:find("%u[%w_]*%.[%w_.]*[%w_]", pos)
        if not first then
          break
        end
        -- Method crefs arrive as `Type.Method(System.Decimal)`; swallow the
        -- parameter list so it is not left stranded outside the span.
        if text:sub(last + 1, last + 1) == "(" then
          local close = text:find(")", last + 1, true)
          if close then
            last = close
          end
        end
        pieces[#pieces + 1] = text:sub(pos, first - 1)
        pieces[#pieces + 1] = "`" .. text:sub(first, last) .. "`"
        pos = last + 1
      end
      pieces[#pieces + 1] = text:sub(pos)
      return table.concat(pieces)
    end

    -- Roslyn's own `<c>` spans are already backticked; only touch the text
    -- between them so those are never wrapped twice.
    local function outside_code_spans(text, fn)
      local pieces = vim.split(text, "`", { plain = true })
      for i = 1, #pieces, 2 do
        pieces[i] = fn(pieces[i])
      end
      return table.concat(pieces, "`")
    end

    local function mark_symbols(line)
      local parts = vim.split(line, "&nbsp;", { plain = true })
      for i = 1, #parts do
        local part = parts[i]
        if i > 1 and i < #parts and looks_like_symbol(part) then
          -- Whole segment sits between two elements: `... two bands —` /
          -- `NavItem.WineTaxCode` / `into this table and`. This is the only rule
          -- that can catch an *unqualified* cref, and it is also the source of
          -- the known false positives -- an isolated capitalised prose word
          -- ("Denmark") is indistinguishable from `<see cref="NavItem"/>`.
          parts[i] = "`" .. part .. "`"
        else
          parts[i] = outside_code_spans(part, mark_qualified)
        end
      end
      return table.concat(parts, "&nbsp;")
    end

    -- Roslyn does not escape inside fenced code blocks, and unescaping there
    -- would corrupt sample code, so those lines pass through untouched.
    local function demarkdown(text)
      local lines, fenced = {}, false
      for line in vim.gsplit(text, "\n", { plain = true }) do
        if line:match("^%s*```") then
          fenced = not fenced
        elseif not fenced then
          -- Unescape first: a cref arrives as `NavItem\.WineTaxCode`, and the
          -- backslash would stop it looking like an identifier. Entities last,
          -- since they are the delimiters `mark_symbols` splits on.
          line = mark_symbols(line:gsub("\\(%p)", "%1")):gsub("&%a+;", html_entities)
        end
        lines[#lines + 1] = line
      end
      return table.concat(lines, "\n")
    end

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

    -- Clients whose hover responses have already been patched, keyed by id.
    local hover_patched = {}

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end

        -- This cannot be a `handlers` entry: `vim.lsp.buf.hover()` goes through
        -- `buf_request_all`, which passes its own inline callback to
        -- `Client:request()` and so skips `_resolve_handler` entirely --
        -- neither `client.handlers` nor `vim.lsp.handlers` is ever consulted.
        -- Wrapping `request` catches the one path actually taken. It also has
        -- to happen here rather than in an `on_init`: nvim-lspconfig ships
        -- roslyn_ls with a *list* of `on_init` hooks that opens the solution or
        -- project, and `vim.lsp.config` merges with `force`, so supplying our
        -- own would silently replace the loader.
        if client.name == "roslyn_ls" and not hover_patched[client.id] then
          hover_patched[client.id] = true
          local request = client.request
          client.request = function(self, method, params, handler, bufnr)
            if method == "textDocument/hover" and handler then
              local inner = handler
              handler = function(err, result, ctx, cfg)
                local contents = result and result.contents
                if type(contents) == "table" and contents.kind == "markdown" and contents.value then
                  contents.value = demarkdown(contents.value)
                end
                return inner(err, result, ctx, cfg)
              end
            end
            return request(self, method, params, handler, bufnr)
          end
        end

        local mapN = function(keys, action, description)
          vim.keymap.set("n", keys, action, { buffer = args.buf, silent = true, noremap = true, desc = description })
        end

        mapN("<leader>cr", vim.lsp.buf.rename, "[R]ename Symbol")
        mapN("<leader>ca", vim.lsp.buf.code_action, "[A]ctions")
        mapN("K", function()
          vim.lsp.buf.hover({ border = "rounded" })
        end, "Hover Documentation")

        if client:supports_method("textDocument/inlayHint") then
          vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          mapN("<leader>ch", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = args.buf })
            vim.notify("Inlay hints " .. (enabled and "disabled" or "enabled"))
          end, "[C]ode Inlay [H]ints")
        end

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
        -- NOTE: `<leader>fs` (document symbols) is mapped globally in
        -- `bh.plugins.snacks`, so it can fall back to Treesitter in buffers
        -- without a language server. Workspace symbols are LSP-only.
        mapN("<leader>fS", function()
          Snacks.picker.lsp_workspace_symbols()
        end, "[F]ind LSP Workspace [S]ymbols")
      end,
    })
  end,
}
