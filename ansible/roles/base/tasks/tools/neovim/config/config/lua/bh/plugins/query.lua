-- Interactive query playground for the current buffer.
--
-- `<leader>q` is a general "query this buffer" verb rather than a jq-specific
-- binding. The mapping is buffer-local and created per filetype, so it exists
-- only where a backend can actually handle the buffer, and each filetype stays
-- free to use a different implementation -- a future csv backend does not have
-- to be reachable through jq-playground.
--
-- The autocommand is registered from `init` (which lazy runs during startup)
-- rather than `config`, so the mappings exist before the plugin is loaded and
-- the plugin itself is still deferred until the first `:JqPlayground`.
--
-- jq-playground.nvim re-reads `require("jq-playground.config").config` on every
-- invocation, so swapping `cmd` immediately before launching retargets it. It
-- appends the query buffer's contents as a single positional argument, then
-- unconditionally appends `--indent N`/`--tab`, then the input filename for
-- unmodified file buffers. Backends routed through it must tolerate that argv
-- shape -- which rules out duckdb and friends for csv, as they accept neither
-- `--indent` nor a data file as a positional argument.
local backends = {
  json = { cmd = { "jq" }, query_ft = "jq", output_ft = "json" },
  jsonc = { cmd = { "jq" }, query_ft = "jq", output_ft = "json" },
  -- The plugin detects YAML on its own and forces `yq`. Listed anyway so the
  -- executable check below reports a missing `yq` instead of letting the
  -- playground open and fail on first query.
  yaml = { cmd = { "yq" }, query_ft = "yq", output_ft = "yaml" },
}

local function open_playground(backend)
  local exe = backend.cmd[1]
  if vim.fn.executable(exe) ~= 1 then
    vim.notify(("'%s' is not installed, cannot query this buffer"):format(exe), vim.log.levels.ERROR)
    return
  end

  local config = require("jq-playground.config").config
  config.cmd = vim.deepcopy(backend.cmd)
  config.query_window.filetype = backend.query_ft
  config.output_window.filetype = backend.output_ft

  vim.cmd.JqPlayground()
end

return {
  "yochem/jq-playground.nvim",
  commit = "8bf7d17677d837e62575ddaa48906f4cc21e89bc",
  cmd = "JqPlayground",
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = vim.tbl_keys(backends),
      callback = function(ev)
        local backend = backends[ev.match]
        vim.keymap.set("n", "<leader>q", function()
          open_playground(backend)
        end, { buffer = ev.buf, desc = "[Q]uery Buffer" })
      end,
    })
  end,
  opts = {},
}
