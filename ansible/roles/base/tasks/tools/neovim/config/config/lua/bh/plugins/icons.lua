return {
  "echasnovski/mini.icons",
  tag = "v0.17.0",
  commit = "ff2e4f1d29f659cc2bad0f9256f2f6195c6b2428",
  config = function()
    local icons = require("mini.icons")
    icons.setup()
    icons.mock_nvim_web_devicons()
  end,
}
