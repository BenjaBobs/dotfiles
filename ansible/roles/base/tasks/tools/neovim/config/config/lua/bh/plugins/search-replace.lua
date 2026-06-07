return {
  "chrisgrieser/nvim-rip-substitute",
  commit = "c65592d88f0fa00396e260da99d9e419f4891e3b",
  cmd = "RipSubstitute",
  opts = {},
  keys = {
    {
      "<leader>fr",
      function()
        require("rip-substitute").sub()
      end,
      mode = { "n", "x" },
      desc = "Search and [R]eplace",
    },
  },
}
