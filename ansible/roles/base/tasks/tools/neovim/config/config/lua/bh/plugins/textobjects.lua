return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    local select = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")
    local swap = require("nvim-treesitter-textobjects.swap")

    -- Select
    local select_maps = {
      ["af"] = "@function.outer",
      ["if"] = "@function.inner",
      ["ac"] = "@class.outer",
      ["ic"] = "@class.inner",
      ["aa"] = "@parameter.outer",
      ["ia"] = "@parameter.inner",
    }
    for key, query in pairs(select_maps) do
      vim.keymap.set({ "x", "o" }, key, function()
        select.select_textobject(query, "textobjects")
      end, { desc = query })
    end

    -- Move
    local next_maps = {
      ["]f"] = "@function.outer",
      ["]a"] = "@parameter.inner",
      ["]c"] = "@class.outer",
    }
    local prev_maps = {
      ["[f"] = "@function.outer",
      ["[a"] = "@parameter.inner",
      ["[c"] = "@class.outer",
    }
    for key, query in pairs(next_maps) do
      vim.keymap.set({ "n", "x", "o" }, key, function()
        move.goto_next_start(query, "textobjects")
      end, { desc = "Next " .. query })
    end
    for key, query in pairs(prev_maps) do
      vim.keymap.set({ "n", "x", "o" }, key, function()
        move.goto_previous_start(query, "textobjects")
      end, { desc = "Previous " .. query })
    end

    -- Swap (parameter only for now)
    for _, key in ipairs({ "<A-S-j>", "<A-S-Down>" }) do
      vim.keymap.set("n", key, function()
        swap.swap_next("@parameter.inner", "textobjects")
      end, { desc = "Swap parameter forward" })
    end
    for _, key in ipairs({ "<A-S-k>", "<A-S-Up>" }) do
      vim.keymap.set("n", key, function()
        swap.swap_previous("@parameter.inner", "textobjects")
      end, { desc = "Swap parameter backward" })
    end
  end,
}
