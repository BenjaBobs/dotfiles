-- Node types considered "large blocks" for vertical swapping.
-- Walks up the tree from the cursor to find the first matching ancestor
-- that has a named sibling to swap with.
local block_types = {
  -- Functions/methods
  function_declaration = true,
  method_definition = true,
  arrow_function = true,
  function_item = true, -- Rust
  -- Classes/types
  class_declaration = true,
  type_alias_declaration = true,
  interface_declaration = true,
  enum_declaration = true,
  -- Declarations
  export_statement = true,
  lexical_declaration = true,
  variable_declaration = true,
  -- Type members
  property_signature = true,
  property_definition = true,
  public_field_definition = true,
}

-- Node types where sibling-swap is appropriate (small inline things)
local inline_parent_types = {
  formal_parameters = true,
  arguments = true,
  type_arguments = true,
  type_parameters = true,
  tuple_type = true,
  union_type = true,
  intersection_type = true,
  array_pattern = true,
  object_pattern = true,
  array = true,
  object = true,
  enum_body = true,
}

local function is_inside_inline_context()
  local node = vim.treesitter.get_node()
  while node do
    if inline_parent_types[node:type()] then
      return true
    end
    if block_types[node:type()] then
      return false
    end
    node = node:parent()
  end
  return false
end

local function guarded_sibling_swap(fn)
  return function()
    if not is_inside_inline_context() then
      vim.notify("Use Alt+Shift+Up/Down for block swap here", vim.log.levels.INFO)
      return
    end
    fn()
  end
end

local function find_block_node(direction)
  local node = vim.treesitter.get_node()
  while node do
    if block_types[node:type()] then
      -- Only return this node if it has a sibling in the desired direction
      local sibling = direction == "next" and node:next_named_sibling() or node:prev_named_sibling()
      -- Skip comments to find a real sibling
      while sibling and sibling:type():match("comment") do
        sibling = direction == "next" and sibling:next_named_sibling() or sibling:prev_named_sibling()
      end
      if sibling then
        return node, sibling
      end
    end
    node = node:parent()
  end
  return nil, nil
end

-- Get the line range of a node including any leading comment siblings
local function get_range_with_comments(n)
  local sr, _, er, _ = n:range()
  local prev = n:prev_named_sibling()
  while prev and prev:type():match("comment") do
    sr = prev:range()
    prev = prev:prev_named_sibling()
  end
  return sr, er
end

local function swap_block(direction)
  local node, sibling = find_block_node(direction)
  if not node then
    vim.notify("No swappable block found", vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_set_cursor
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_row, cur_col = cur_pos[1] - 1, cur_pos[2] -- 0-indexed

  local a_sr, a_er = get_range_with_comments(node)
  local b_sr, b_er = get_range_with_comments(sibling)

  -- Remember cursor offset relative to our block (a)
  local row_offset = cur_row - a_sr

  -- Ensure top/bottom ordering
  local top_sr, top_er, bot_sr, bot_er
  local a_is_top = a_sr < b_sr
  if a_is_top then
    top_sr, top_er, bot_sr, bot_er = a_sr, a_er, b_sr, b_er
  else
    top_sr, top_er, bot_sr, bot_er = b_sr, b_er, a_sr, a_er
  end

  local top_lines = vim.api.nvim_buf_get_lines(buf, top_sr, top_er + 1, false)
  local bot_lines = vim.api.nvim_buf_get_lines(buf, bot_sr, bot_er + 1, false)

  -- Replace bottom first to preserve top line numbers
  vim.api.nvim_buf_set_lines(buf, bot_sr, bot_er + 1, false, top_lines)
  vim.api.nvim_buf_set_lines(buf, top_sr, top_er + 1, false, bot_lines)

  -- Place cursor at same relative position within our block
  local new_block_start
  if a_is_top then
    -- Our block moved down: starts at bot_sr, shifted by size difference
    new_block_start = bot_sr + (#bot_lines - #top_lines)
  else
    -- Our block moved up: starts at top_sr
    new_block_start = top_sr
  end
  cursor(0, { new_block_start + row_offset + 1, cur_col })
end

return {
  -- Treesitter textobjects: select and move
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

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

      -- Incremental selection (Neovim 0.12 built-in)
      vim.keymap.set("n", "+", "van", { desc = "Enter Visual + grow selection", remap = true })
      vim.keymap.set("x", "+", "an", { desc = "Grow selection", remap = true })
      vim.keymap.set("x", "-", "in", { desc = "Shrink selection", remap = true })
    end,
  },

  -- Sibling swap: for small inline nodes (parameters, types, object keys)
  {
    "Wansmer/sibling-swap.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      use_default_keymaps = false,
    },
    keys = {
      { "<A-S-Right>", guarded_sibling_swap(function() require("sibling-swap").swap_with_right() end), desc = "Swap inline node right" },
      { "<A-S-l>", guarded_sibling_swap(function() require("sibling-swap").swap_with_right() end), desc = "Swap inline node right" },
      { "<A-S-Left>", guarded_sibling_swap(function() require("sibling-swap").swap_with_left() end), desc = "Swap inline node left" },
      { "<A-S-h>", guarded_sibling_swap(function() require("sibling-swap").swap_with_left() end), desc = "Swap inline node left" },
      -- Block swap: functions, classes, types, etc.
      { "<A-S-Down>", function() swap_block("next") end, desc = "Swap block down" },
      { "<A-S-j>", function() swap_block("next") end, desc = "Swap block down" },
      { "<A-S-Up>", function() swap_block("prev") end, desc = "Swap block up" },
      { "<A-S-k>", function() swap_block("prev") end, desc = "Swap block up" },
    },
  },
}
