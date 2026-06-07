return {
  "A7Lavinraj/fyler.nvim",
  tag = "v2.0.0",
  commit = "bb8b9f30c652c948d35211958b0deec3496bcc08",
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
