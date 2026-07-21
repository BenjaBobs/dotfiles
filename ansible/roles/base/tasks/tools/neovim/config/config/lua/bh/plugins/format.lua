return {
  "stevearc/conform.nvim",
  tag = "v9.1.0",
  commit = "3543d000dafbc41cc7761d860cfdb24e82154f75",
  config = function()
    local conform = require("conform")
    local dotnet_tools = vim.fn.expand("~/.dotnet/tools")
    local csharpier = dotnet_tools .. "/csharpier"

    local formatters = {
      -- Requires the `kulala-fmt` CLI on PATH (npm/bun i -g
      -- @mistweaverco/kulala-fmt). NOTE: the formatter name uses a hyphen —
      -- `kulala_fmt` (underscore) is not a valid formatter.
      --
      -- We drive it through its stdin interface (`fix --stdin`) rather than
      -- conform's builtin `format $FILENAME`: the current v4 CLI hangs on the
      -- file-argument form (times out), but reads stdin and writes the
      -- formatted result to stdout cleanly.
      ["kulala-fmt"] = {
        command = "kulala-fmt",
        args = { "fix", "--stdin" },
        stdin = true,
      },
    }

    if vim.fn.executable(csharpier) == 1 then
      formatters.csharpier = {
        command = csharpier,
        args = { "format", "--stdin-path", "$FILENAME" },
        stdin = true,
      }
    end

    -- mdslw: one sentence per line ("semantic line breaks"). `--max-width 0`
    -- disables wrapping so each sentence stays on a single line regardless of
    -- length; drop it (default 80) if you also want long sentences wrapped.
    -- Requires the `mdslw` CLI on PATH (https://github.com/razziel89/mdslw).
    --
    -- `--suppressions` lists words ending in `.`/`?`/`!`/`:` that must NOT cause
    -- a line break. mdslw's `--lang` covers de/en/es/fr/it but not Danish, and
    -- it has no "period-before-lowercase" heuristic, so Danish abbreviations are
    -- enumerated here (English ones come from the default `--lang ac`). Extend
    -- the list as needed.
    formatters.mdslw = {
      prepend_args = {
        "--max-width",
        "0",
        "--suppressions",
        "pr. bl.a. ca. dvs. eks. ekskl. evt. f.eks. fx. hhv. inkl. jf. kl. kr. "
          .. "m.fl. m.m. m.v. mht. mv. nr. osv. pga. stk. tlf. vedr. vha. "
          .. "iflg. ift. ang. afd. fig.",
      },
    }

    conform.setup({
      formatters = formatters,
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
        -- prettier normalizes block structure (e.g. blank lines around headings,
        -- lists, tables); mdslw then splits prose one sentence per line. Order
        -- matters: prettier runs first, mdslw last. prettier's default
        -- proseWrap="preserve" keeps mdslw's line breaks, so the chain is stable.
        markdown = { "prettier", "mdslw" },
        cs = { "csharpier" },
        lua = { "stylua" },
        http = { "kulala-fmt" },
        rest = { "kulala-fmt" },
      },
    
      format_on_save = function(bufnr)
        if vim.tbl_contains({ "http", "rest" }, vim.bo[bufnr].filetype) then
          -- Format with kulala-fmt only. Never fall back to the kulala
          -- LSP: its formatting inserts a leading `###` that demotes document
          -- variables into the first request block and breaks them.
          return { timeout_ms = 3000, lsp_format = "never" }
        end

        return {
          timeout_ms = 2000, -- Timeout (in ms) for formatting.
          lsp_format = "fallback", -- If no formatter is available for the filetype, fall back to LSP formatting.
          async = false,
        }
      end,
    })

    vim.keymap.set("n", "<leader>bf", function()
      conform.format({ async = true, lsp_format = "fallback" })
    end, { desc = "[F]ormat" })

    vim.keymap.set("n", "<leader>bw", ":noau w", { desc = "[W]rite without formatting" })
  end,
}
