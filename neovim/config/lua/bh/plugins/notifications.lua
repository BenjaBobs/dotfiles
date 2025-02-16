return {
  "rcarriga/nvim-notify",
  dependencies = {
    "mrded/nvim-lsp-notify",
  },
  config = function()
    local notify = require("notify")
    notify.setup()

    require("lsp-notify").setup({ notify = notify })
  end,
}
