return {
  "nvim-treesitter/nvim-treesitter-context",
  -- No current semver release tag; pin the current branch commit.
  commit = "b311b30818951d01f7b4bf650521b868b3fece16",
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter",
      -- Release tags lag the current main branch and use the old setup API.
      commit = "4916d6592ede8c07973490d9322f187e07dfefac",
    },
  },
  -- Spelled out because `keys` would otherwise flip this spec to lazy and leave
  -- the sticky context off until the first press.
  lazy = false,
  keys = {
    {
      "<leader>cc",
      function()
        local context = require("treesitter-context")
        context.toggle()
        vim.notify(
          "Sticky context " .. (context.enabled() and "enabled" or "disabled"),
          vim.log.levels.INFO,
          { title = "treesitter-context" }
        )
      end,
      desc = "Toggle Sticky [C]ontext",
    },
  },
  opts = {},
}
