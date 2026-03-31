return {
  "chrisgrieser/nvim-rulebook",
  keys = {
    { "<leader>ri", function() require("rulebook").ignoreRule() end, desc = "[R]ule [I]gnore" },
    { "<leader>rl", function() require("rulebook").lookupRule() end, desc = "[R]ule [L]ookup" },
    { "<leader>ry", function() require("rulebook").yankDiagnosticCode() end, desc = "[R]ule [Y]ank code" },
    { "<leader>rf", function() require("rulebook").suppressFormatter() end, mode = { "n", "x" }, desc = "[R]ule suppress [F]ormatter" },
  },
}
