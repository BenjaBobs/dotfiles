return {
  "A7Lavinraj/fyler.nvim",
  branch = "stable",
  opts = {
    integrations = {
      winpick = "snacks",
    },
    views = {
      finder = {
        default_explorer = true,
        icon = {
          directory_collapsed = "",
          directory_expanded = "",
          directory_empty = "",
        },
        mappings = {
          ["<CR>"] = "Select",
          ["l"] = "Select",
          ["<Right>"] = "Select",
          ["h"] = "CollapseNode",
          ["<Left>"] = "CollapseNode",
        },
        win = {
          kind = "float",
          kinds = {
            float = {
              height = "80%",
              width = "80%",
              top = "8%",
              left = "10%",
            },
          },
        },
      },
    },
  },
  lazy = false,
}
