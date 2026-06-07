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
  opts = {},
}
