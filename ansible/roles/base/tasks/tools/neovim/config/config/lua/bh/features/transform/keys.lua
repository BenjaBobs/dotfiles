-- `<leader>ct` -- [C]ode [T]ransform (see bh/transform/).
vim.keymap.set({ "n", "x" }, "<leader>ct", function()
  require("bh.features.transform").open()
end, { desc = "[T]ransform" })
