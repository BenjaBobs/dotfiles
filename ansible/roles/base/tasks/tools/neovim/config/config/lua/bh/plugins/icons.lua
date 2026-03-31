return {
  "echasnovski/mini.icons",
  version = "*",
  config = function()
    local icons = require("mini.icons")
    icons.setup()
    icons.mock_nvim_web_devicons()
  end,
}
