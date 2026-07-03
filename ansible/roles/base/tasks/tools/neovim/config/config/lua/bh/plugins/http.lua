return {
  "mistweaverco/kulala.nvim",
  tag = "v6.20.6",
  commit = "4809552cfeba51dd4630dfd4a31513e9b19dcfd3",
  ft = { "http", "rest" },
  opts = {
    default_env = "dev",
    debug = 0,
    ui = {
      default_view = "body",
    },
  },
  config = function(_, opts)
    require("kulala").setup(opts)

    local function set_keymaps(buf)
      vim.keymap.set("n", "<CR>", function()
        require("kulala").run()
      end, { buffer = buf, desc = "Kulala: send request" })
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "http", "rest" },
      callback = function(ev)
        set_keymaps(ev.buf)
      end,
    })

    -- Apply to the buffer that triggered lazy-loading this plugin.
    if vim.tbl_contains({ "http", "rest" }, vim.bo.filetype) then
      set_keymaps(0)
    end
  end,
}
