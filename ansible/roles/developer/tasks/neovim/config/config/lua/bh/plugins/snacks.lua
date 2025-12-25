return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below

    -- https://github.com/folke/snacks.nvim/blob/main/docs/bigfile.md
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    explorer = { enabled = true }, -- maybe turn off?
    indent = { enabled = false },
    input = { enabled = true },
    picker = { enabled = true }, -- replaces telescope maybe?
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = false }, -- didn't like this
    statuscolumn = { enabled = true },
    words = { enabled = true },
    terminal = {},
  },
  keys = {
    {
      "<leader>ff",
      function()
        Snacks.picker.files()
      end,
      desc = "[F]ind [F]iles",
    },
    {
      "<leader>fg",
      function()
        Snacks.picker.grep()
      end,
      desc = "[F]ind [G]rep",
    },
    {
      "<leader>fh",
      function()
        Snacks.picker.help()
      end,
      desc = "[F]ind [H]elp",
    },
    {
      "<leader>fk",
      function()
        Snacks.picker.keymaps()
      end,
      desc = "[F]ind [K]eymaps",
    },
    {
      "<leader>fn",
      function()
        Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
      end,
      desc = "[F]ind [N]eovim File",
    },
    {
      "<leader>fb",
      function()
        Snacks.picker.lines()
      end,
      desc = "[F]ind in [B]uffer",
    },
    {
      "<leader>fo",
      function()
        Snacks.picker.buffers()
      end,
      desc = "[F]ind [O]pen Buffers",
    },
    {
      "<leader>fe",
      function()
        Snacks.picker.diagnostics()
      end,
      desc = "[F]ind [E]rror",
    },
    {
      "<leader>gb",
      function()
        Snacks.picker.git_branches()
      end,
      desc = "[G]it [B]ranches",
    },
    {
      "<leader>gs",
      function()
        Snacks.picker.git_status()
      end,
      desc = "[G]it [S]tatus",
    },
  },
  init = function()
    -- LSP Progress
    ---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
    local progress = vim.defaulttable()
    vim.api.nvim_create_autocmd("LspProgress", {
      ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
        if not client or type(value) ~= "table" then
          return
        end
        local p = progress[client.id]

        for i = 1, #p + 1 do
          if i == #p + 1 or p[i].token == ev.data.params.token then
            p[i] = {
              token = ev.data.params.token,
              msg = ("[%3d%%] %s%s"):format(
                value.kind == "end" and 100 or value.percentage or 100,
                value.title or "",
                value.message and (" **%s**"):format(value.message) or ""
              ),
              done = value.kind == "end",
            }
            break
          end
        end

        local msg = {} ---@type string[]
        progress[client.id] = vim.tbl_filter(function(v)
          return table.insert(msg, v.msg) or not v.done
        end, p)

        local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
        vim.notify(table.concat(msg, "\n"), "info", {
          id = "lsp_progress",
          title = client.name,
          opts = function(notif)
            notif.icon = #progress[client.id] == 0 and " "
              or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
          end,
        })
      end,
    })
  end,
}
