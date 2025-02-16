return {
  "stevearc/overseer.nvim",
  config = function()
    local overseer = require("overseer").setup({
      templates = { "builtin" },
    })

    local telescope = require("telescope.builtin")

    -- todo: https://github.com/sakuemon/telescope-overseer.nvim/blob/main/lua/telescope/_extensions/overseer.lua
  end,
}
