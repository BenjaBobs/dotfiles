return {
  "chrisgrieser/nvim-rulebook",
  commit = "083dd66b498bc142386a7c96dddab73acbf4ec20",
  keys = {
    {
      "<leader>cI",
      function()
        require("rulebook").ignoreRule()
      end,
      desc = "Rule [I]gnore",
    },
    {
      "<leader>cL",
      function()
        require("rulebook").lookupRule()
      end,
      desc = "Rule [L]ookup",
    },
    {
      "<leader>cY",
      function()
        require("rulebook").yankDiagnosticCode()
      end,
      desc = "Rule [Y]ank code",
    },
    {
      "<leader>cF",
      function()
        require("rulebook").suppressFormatter()
      end,
      mode = { "n", "x" },
      desc = "Rule suppress [F]ormatter",
    },
  },
}
