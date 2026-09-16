-- Node types considered "large blocks" for vertical swapping.
-- Walks up the tree from the cursor to find the first matching ancestor
-- that has a named sibling to swap with.
--
-- `true` means "any named sibling is a valid partner", which holds for the
-- JS/TS shapes below: they sit in bodies where every sibling is another
-- declaration. A table refines that, which SQL needs:
--   parent     - only count as a block when the parent is one of these
--   not_parent - never count as a block under one of these parents
--   same_type  - only swap with a sibling of the same type
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
  -- JS's `var x = 1`. C# reuses the name for the `int _b = 2` *inside* a
  -- `field_declaration`, where the line you mean is the parent and the previous
  -- sibling is the `private` modifier -- so the walk used to stop here and swap
  -- a declaration with a modifier on the same row, which changes nothing and
  -- reports nothing. Excluding those parents lets it reach the real block.
  variable_declaration = {
    not_parent = {
      field_declaration = true,
      event_field_declaration = true,
      local_declaration_statement = true,
      using_statement = true,
      for_statement = true,
    },
  },
  -- Type members
  property_signature = true,
  property_definition = true,
  public_field_definition = true,

  -- C#. The names barely overlap with the JS/TS ones above -- a method is
  -- `method_definition` there and `method_declaration` here, parameters are
  -- `formal_parameters` there and `parameter_list` here -- so before this block
  -- the only C# node either table matched was `class_declaration`, which has no
  -- sibling to swap with in a one-class-per-file codebase. That is why every
  -- swap in a C# buffer answered "No swappable block found".
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  property_declaration = true,
  field_declaration = true,
  event_field_declaration = true,
  indexer_declaration = true,
  operator_declaration = true,
  delegate_declaration = true,
  record_declaration = true,
  struct_declaration = true,
  namespace_declaration = true,
  file_scoped_namespace_declaration = true,
  using_directive = true,
  -- Enum members are one per line in any enum big enough to reorder, so they go
  -- on the vertical keys; that is also why `enum_member_declaration_list` is
  -- absent from the inline table below, where it would be unreachable.
  enum_member_declaration = true,
  local_declaration_statement = true,

  -- SQL. `statement` is both a top-level statement and the body of a CTE; only
  -- the former has statements either side of it, so it is restricted to the
  -- three containers that actually hold a list of them. That restriction is
  -- also what lets the walk fall through to `cte` when the cursor is inside a
  -- CTE body, which is the swap you want there.
  statement = { parent = { program = true, block = true, transaction = true } },
  -- The rest sit among siblings of other kinds -- a `cte` is followed by the
  -- `select` that consumes it, a `join` by the `where` after it -- so each is
  -- pinned to its own type rather than swapping across the boundary.
  -- `cte` is deliberately absent: CTEs are comma-separated, and a line-based
  -- swap cannot move a separator that belongs to the position rather than to
  -- either node. The walk falls through to the enclosing `statement`, which
  -- moves the whole `WITH ...` query -- safe, if blunter.
  join = { same_type = true },
}

-- Whether `node` counts as a swappable block here, returning its rule (a
-- possibly empty table) or nil.
local function block_rule(node)
  local rule = block_types[node:type()]
  if rule == nil then
    return nil
  end
  if rule == true then
    return {}
  end
  if rule.parent or rule.not_parent then
    local parent = node:parent()
    if rule.parent and not (parent and rule.parent[parent:type()]) then
      return nil
    end
    if rule.not_parent and parent and rule.not_parent[parent:type()] then
      return nil
    end
  end
  return rule
end

-- Siblings that are never the intended swap partner.
--
-- The comment case is the obvious one. The keyword case is SQL: its grammar
-- makes every keyword a *named* node -- `keyword_from`, `keyword_as`, and 369
-- others -- so "next named sibling" otherwise lands on a bare `AS` and swaps a
-- statement with it.
local function is_skippable_sibling(node)
  local t = node:type()
  -- `modifier` is C#'s `public`/`private`/`static`: a sibling of the thing you
  -- are moving, never a swap partner for it.
  return t:match("comment") ~= nil or t:match("^keyword_") ~= nil or t == "modifier"
end

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

  -- C#: the comma-separated lists.
  parameter_list = true,
  argument_list = true,
  type_parameter_list = true,
  type_argument_list = true,
  bracketed_parameter_list = true,
  bracketed_argument_list = true,
  attribute_argument_list = true,
  attribute_list = true,
  -- `new[] { 1, 2, 3 }` and `new Foo { A = 1, B = 2 }`
  initializer_expression = true,
  tuple_expression = true,

  -- SQL: the comma-separated lists.
  --
  -- `order_by` and `column_definitions` are deliberately absent. sibling-swap
  -- always works at the innermost sibling level, which inside `x DESC` is
  -- `x`↔`DESC` and inside `id INT` is `id`↔`INT` -- it produces `ORDER BY DESC
  -- x` and `INT id` rather than reordering across the commas. Declining is
  -- better than corrupting, so the guard falls through to the block keys, which
  -- move the whole statement. `group_by` has no such wrapper node and works.
  select_expression = true,
  list = true,
  -- `UPDATE ... SET a = 1, b = 2` puts the assignments straight under `update`
  -- with no `assignment_list` wrapper, so the walk has to recognise the item
  -- itself rather than a container.
  assignment = true,
  assignment_list = true,
  ordered_columns = true,
  group_by = true,
}

local function is_inside_inline_context()
  local node = vim.treesitter.get_node()
  while node do
    if inline_parent_types[node:type()] then
      return true
    end
    if block_rule(node) then
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
    local rule = block_rule(node)
    if rule then
      -- Only return this node if it has a sibling in the desired direction
      local sibling = direction == "next" and node:next_named_sibling() or node:prev_named_sibling()
      -- Skip comments, keywords and -- where the rule asks for it -- siblings of
      -- another type, to find a real partner
      while sibling and (is_skippable_sibling(sibling) or (rule.same_type and sibling:type() ~= node:type())) do
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

-- Does this node have its lines to itself?
--
-- Swapping is line-based, so a node that begins or ends part-way through a line
-- drags its neighbours along: the first CTE in `WITH first AS (` starts after
-- `WITH`, and swapping those lines carries the keyword off with it.
--
-- A trailing `;` is fine and a trailing `,` is not, which looks arbitrary but is
-- the whole distinction: `;` *terminates* an item, so every item has one and it
-- travels correctly. `,` *separates* them, so only the non-final items have one
-- and it belongs to the position rather than the node -- swap the lines and the
-- comma ends up after the last item.
local function owns_its_lines(node)
  local sr, sc, er, ec = node:range()
  local first = vim.api.nvim_buf_get_lines(0, sr, sr + 1, false)[1] or ""
  local last = vim.api.nvim_buf_get_lines(0, er, er + 1, false)[1] or ""
  if first:sub(1, sc):match("%S") then
    return false
  end
  if last:sub(ec + 1):match("[^%s;]") then
    return false
  end
  return true
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

  -- Two nodes can share a line: consecutive CTEs both touch the `), ` that
  -- separates them. This swap is line-based, so a shared line would be written
  -- twice and destroy both nodes. Refuse rather than corrupt.
  if top_er >= bot_sr then
    vim.notify("Blocks share a line, cannot swap line-wise", vim.log.levels.WARN)
    return
  end

  if not (owns_its_lines(node) and owns_its_lines(sibling)) then
    vim.notify("Block does not own its lines, cannot swap line-wise", vim.log.levels.WARN)
    return
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
    commit = "851e865342e5a4cb1ae23d31caf6e991e1c99f1e",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        -- Release tags lag the current main branch and use the old setup API.
        commit = "4916d6592ede8c07973490d9322f187e07dfefac",
      },
    },
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
    commit = "ae5aef7e62faf16228d570757e97ca92bf49f849",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        -- Release tags lag the current main branch and use the old setup API.
        commit = "4916d6592ede8c07973490d9322f187e07dfefac",
      },
    },
    opts = {
      use_default_keymaps = false,
    },
    keys = {
      {
        "<A-S-Right>",
        guarded_sibling_swap(function()
          require("sibling-swap").swap_with_right()
        end),
        desc = "Swap inline node right",
      },
      {
        "<A-S-l>",
        guarded_sibling_swap(function()
          require("sibling-swap").swap_with_right()
        end),
        desc = "Swap inline node right",
      },
      {
        "<A-S-Left>",
        guarded_sibling_swap(function()
          require("sibling-swap").swap_with_left()
        end),
        desc = "Swap inline node left",
      },
      {
        "<A-S-h>",
        guarded_sibling_swap(function()
          require("sibling-swap").swap_with_left()
        end),
        desc = "Swap inline node left",
      },
      -- Block swap: functions, classes, types, etc.
      {
        "<A-S-Down>",
        function()
          swap_block("next")
        end,
        desc = "Swap block down",
      },
      {
        "<A-S-j>",
        function()
          swap_block("next")
        end,
        desc = "Swap block down",
      },
      {
        "<A-S-Up>",
        function()
          swap_block("prev")
        end,
        desc = "Swap block up",
      },
      {
        "<A-S-k>",
        function()
          swap_block("prev")
        end,
        desc = "Swap block up",
      },
    },
  },
}
