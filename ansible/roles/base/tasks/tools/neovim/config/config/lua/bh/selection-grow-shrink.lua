-- selection.lua — Smart incremental selection for Neovim.
--
-- Uses native vim.treesitter (get_node + parent) to walk the AST.
-- No nvim-treesitter plugin module config needed — just a parser.
-- Falls back to bracket / quote / word expansion when no parser exists.
--
-- Normal mode:
--   +  -> enter Visual and grow once
--   -  -> enter Visual (1-char, no grow)
--
-- Visual mode:
--   +  -> grow selection to next TS parent node / fallback pair
--   -  -> shrink back (exact undo via stack)

local M = {}

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local STOP_SPACE = { [" "] = true, ["\t"] = true, ["\n"] = true }
local OPENERS = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local SYM = { ['"'] = true, ["'"] = true, ["`"] = true }

-------------------------------------------------------------------------------
-- Low-level helpers
-------------------------------------------------------------------------------

--- Single offset for distance comparisons (1-indexed pos → 0-based offset).
local function abs_offset(buf, p)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, p[1], false)
  local sum = 0
  for i = 1, #lines - 1 do
    sum = sum + #lines[i] + 1
  end
  return sum + (p[2] - 1)
end

--- Span size of a candidate selection.
local function sel_span(buf, L, R)
  return abs_offset(buf, R) - abs_offset(buf, L)
end

--- Step one character forward (dir=1) or backward (dir=-1).
--- Positions are 1-indexed {line, col}, col in 1..#line.
local function step_pos(buf, p, dir)
  local l, c = p[1], p[2]
  local line = vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1] or ""
  local len = #line
  if dir == 1 then
    if c < len then
      return { l, c + 1 }
    end
    if l >= vim.api.nvim_buf_line_count(buf) then
      return nil
    end
    return { l + 1, 1 }
  else
    if c > 1 then
      return { l, c - 1 }
    end
    if l <= 1 then
      return nil
    end
    local prev = vim.api.nvim_buf_get_lines(buf, l - 2, l - 1, false)[1] or ""
    return { l - 1, math.max(#prev, 1) }
  end
end

local function char_at(buf, p)
  local line = vim.api.nvim_buf_get_lines(buf, p[1] - 1, p[1], false)[1] or ""
  if p[2] < 1 or p[2] > #line then
    return nil
  end
  return line:sub(p[2], p[2])
end

-------------------------------------------------------------------------------
-- Geometry: does candidate [cL,cR] strictly grow current [L,R]?
-------------------------------------------------------------------------------

local function sel_grew(L, R, cL, cR)
  local l_eq = (L[1] == cL[1] and L[2] == cL[2])
  local r_eq = (R[1] == cR[1] and R[2] == cR[2])
  if l_eq and r_eq then
    return false
  end -- same size
  local l_ok = (cL[1] < L[1]) or (cL[1] == L[1] and cL[2] <= L[2])
  local r_ok = (cR[1] > R[1]) or (cR[1] == R[1] and cR[2] >= R[2])
  return l_ok and r_ok
end

-------------------------------------------------------------------------------
-- Visual selection read / write
-------------------------------------------------------------------------------

--- Current visual selection as two 1-indexed {line, col}, left <= right.
local function get_visual_lr()
  local v = vim.fn.getpos("v")
  local c = vim.fn.getpos(".")
  local l1, c1 = v[2], v[3]
  local l2, c2 = c[2], c[3]
  if (l1 < l2) or (l1 == l2 and c1 <= c2) then
    return { l1, c1 }, { l2, c2 }
  end
  return { l2, c2 }, { l1, c1 }
end

--- Apply a visual selection [L, R] without nuking the shrink stack.
--- The key problem: we must briefly leave visual to reposition the anchor,
--- which fires ModeChanged. We guard the stack with a flag.
local function set_visual_lr(L, R)
  local mode = vim.fn.mode()
  if mode:find("[vV\22]") then
    vim.b._vis_sel_guard = true
    vim.cmd("normal! \27") -- Esc
    vim.b._vis_sel_guard = false
  end
  vim.api.nvim_win_set_cursor(0, { L[1], L[2] - 1 })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { R[1], R[2] - 1 })
end

-------------------------------------------------------------------------------
-- Selection stack (for shrink / undo)
-------------------------------------------------------------------------------

local function push_sel(buf, L, R)
  -- vim.b returns a COPY each time you read it, so we must read, modify,
  -- then write back.
  local st = vim.b._vis_sel_stack or {}
  table.insert(st, { buf = buf, L = L, R = R })
  vim.b._vis_sel_stack = st
end

local function pop_sel()
  local st = vim.b._vis_sel_stack
  if not st or #st == 0 then
    return nil
  end
  local entry = table.remove(st)
  vim.b._vis_sel_stack = st -- write back the modified table
  return entry
end

local function clear_stack()
  vim.b._vis_sel_stack = {}
end

-------------------------------------------------------------------------------
-- Treesitter: native node walking
-------------------------------------------------------------------------------

--- Check if the current buffer has a working treesitter parser.
local function has_ts_parser()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  return ok and parser ~= nil
end

--- Grow the current visual selection [L, R] to the smallest TS node that
--- strictly contains it. Returns new {L, R} or nil.
local function ts_grow(buf, L, R)
  -- Parse to ensure tree is fresh.
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return nil
  end
  pcall(parser.parse, parser)

  -- Converts TS 0-based exclusive range to our 1-indexed inclusive format.
  local function ts_range_to_lr(sr, sc, er, ec)
    local nL = { sr + 1, sc + 1 }
    local nR
    if ec == 0 then
      -- Node ends at start of row er, so last content is on the previous line.
      local prev_line = vim.api.nvim_buf_get_lines(buf, er - 1, er, false)[1] or ""
      nR = { er, math.max(#prev_line, 1) }
    else
      nR = { er + 1, ec }
    end
    return nL, nR
  end

  -- Walk upward from a given start node, returning the first node that
  -- strictly grows [L, R].
  local function walk_up(node)
    while node do
      local nL, nR = ts_range_to_lr(node:range())
      if sel_grew(L, R, nL, nR) then
        return nL, nR
      end
      node = node:parent()
    end
    return nil
  end

  -- Try from L position first (most common), then R (helps when cursor
  -- is at the edge of a node or the selection spans a boundary).
  local node_l = vim.treesitter.get_node({ bufnr = buf, pos = { L[1] - 1, L[2] - 1 } })
  local node_r = vim.treesitter.get_node({ bufnr = buf, pos = { R[1] - 1, R[2] - 1 } })

  local best_L, best_R
  local best_span = math.huge

  for _, node in ipairs({ node_l, node_r }) do
    if node then
      local nL, nR = walk_up(node)
      if nL then
        local sp = sel_span(buf, nL, nR)
        if sp < best_span then
          best_L, best_R, best_span = nL, nR, sp
        end
      end
    end
  end

  if best_L then
    return best_L, best_R
  end
  return nil
end

-------------------------------------------------------------------------------
-- Fallback candidate finders
-------------------------------------------------------------------------------

--- Find enclosing bracket pairs. Returns list of {L, R} candidates.
local function find_enclosing_brackets(L, R)
  local save = vim.fn.getpos(".")
  local candidates = {}

  for open, close in pairs(OPENERS) do
    -- Place cursor at the right edge of the selection and search backward
    -- for an unmatched opener.
    vim.api.nvim_win_set_cursor(0, { R[1], R[2] - 1 })
    local result = vim.fn.searchpairpos(vim.pesc(open), "", vim.pesc(close), "bnW")
    local ol, oc = result[1], result[2]
    if ol ~= 0 then
      -- Found opener — find its matching closer.
      vim.api.nvim_win_set_cursor(0, { ol, oc - 1 })
      local cresult = vim.fn.searchpairpos(vim.pesc(open), "", vim.pesc(close), "nW")
      local cl, cc = cresult[1], cresult[2]
      if cl ~= 0 then
        local cL, cR = { ol, oc }, { cl, cc }
        if sel_grew(L, R, cL, cR) then
          table.insert(candidates, { cL, cR })
        end
      end
    end
  end

  vim.fn.setpos(".", save)
  return candidates
end

--- Vim regex pattern for an unescaped occurrence of a symmetric delimiter.
local function sym_pattern(sym)
  if sym == '"' then
    return [[\\\@<!"]]
  elseif sym == "'" then
    return [[\\\@<!']]
  elseif sym == "`" then
    return [[\\\@<!`]]
  end
  return vim.pesc(sym)
end

--- Find symmetric quote pairs around selection. Returns list of {L, R}.
local function find_enclosing_quotes(L, R)
  local save = vim.fn.getpos(".")
  local candidates = {}

  for sym, _ in pairs(SYM) do
    local pat = sym_pattern(sym)

    -- Search backward from before L.
    vim.api.nvim_win_set_cursor(0, { L[1], math.max(L[2] - 2, 0) })
    local lresult = vim.fn.searchpos(pat, "bcnW")
    local ll, lc = lresult[1], lresult[2]
    if ll == 0 then
      goto continue
    end

    -- Must be strictly before L (delimiter is not part of inner content).
    if (ll > L[1]) or (ll == L[1] and lc >= L[2]) then
      goto continue
    end

    -- Search forward from after R.
    vim.api.nvim_win_set_cursor(0, { R[1], R[2] }) -- 0-indexed, so this is col after R
    local rresult = vim.fn.searchpos(pat, "nW")
    local rl, rc = rresult[1], rresult[2]
    if rl == 0 then
      goto continue
    end

    -- Must be strictly after R.
    if (rl < R[1]) or (rl == R[1] and rc <= R[2]) then
      goto continue
    end

    -- Not degenerate.
    if ll == rl and lc == rc then
      goto continue
    end

    local cL, cR = { ll, lc }, { rl, rc }
    if sel_grew(L, R, cL, cR) then
      table.insert(candidates, { cL, cR })
    end

    ::continue::
  end

  vim.fn.setpos(".", save)
  return candidates
end

--- Expand to word boundaries (non-whitespace chunk).
local function expand_to_word(buf, L, R)
  local left = { L[1], L[2] }
  while true do
    local prev = step_pos(buf, left, -1)
    if not prev then
      break
    end
    local ch = char_at(buf, prev)
    if not ch or STOP_SPACE[ch] then
      break
    end
    left = prev
  end
  local right = { R[1], R[2] }
  while true do
    local nxt = step_pos(buf, right, 1)
    if not nxt then
      break
    end
    local ch = char_at(buf, nxt)
    if not ch or STOP_SPACE[ch] then
      break
    end
    right = nxt
  end
  return left, right
end

-------------------------------------------------------------------------------
-- Core expand / shrink
-------------------------------------------------------------------------------

local function do_expand()
  local buf = vim.api.nvim_get_current_buf()
  local L, R = get_visual_lr()

  -- 1) Try treesitter first — this gives the best results for code.
  if has_ts_parser() then
    local nL, nR = ts_grow(buf, L, R)
    if nL and nR then
      push_sel(buf, L, R)
      set_visual_lr(nL, nR)
      return
    end
  end

  -- 2) Fallback: gather ALL candidate enclosing structures and pick tightest.
  local candidates = {}

  for _, pair in ipairs(find_enclosing_brackets(L, R)) do
    table.insert(candidates, pair)
  end

  for _, pair in ipairs(find_enclosing_quotes(L, R)) do
    table.insert(candidates, pair)
  end

  local wL, wR = expand_to_word(buf, L, R)
  if sel_grew(L, R, wL, wR) then
    table.insert(candidates, { wL, wR })
  end

  if #candidates > 0 then
    -- Sort by span size ascending — tightest first.
    table.sort(candidates, function(a, b)
      return sel_span(buf, a[1], a[2]) < sel_span(buf, b[1], b[2])
    end)
    push_sel(buf, L, R)
    set_visual_lr(candidates[1][1], candidates[1][2])
    return
  end

  -- 3) Last resort: expand by one char each direction.
  local eL = step_pos(buf, L, -1) or L
  local eR = step_pos(buf, R, 1) or R
  push_sel(buf, L, R)
  set_visual_lr(eL, eR)
end

local function do_shrink()
  local prev = pop_sel()
  if prev then
    set_visual_lr(prev.L, prev.R)
  end
  -- If nothing in the stack, do nothing — we're already at the smallest
  -- selection the user started with.
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.expand()
  do_expand()
end

function M.shrink()
  do_shrink()
end

function M.expand_from_normal()
  clear_stack()
  vim.cmd("normal! v")
  do_expand()
end

function M.shrink_from_normal()
  clear_stack()
  -- In normal mode, "-" just enters visual (1 char). No shrink to do.
  vim.cmd("normal! v")
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

local _setup_done = false

function M.setup()
  if _setup_done then
    return
  end
  _setup_done = true

  vim.keymap.set("x", "+", M.expand, { desc = "Grow selection" })
  vim.keymap.set("x", "-", M.shrink, { desc = "Shrink selection" })
  vim.keymap.set("n", "+", M.expand_from_normal, { desc = "Enter Visual + grow" })
  vim.keymap.set("n", "-", M.shrink_from_normal, { desc = "Enter Visual" })

  -- Clear the stack when the user manually leaves visual mode
  -- (but NOT when set_visual_lr temporarily escapes).
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = { "[vV\22]*:[^vV\22]*" },
    callback = function()
      if not vim.b._vis_sel_guard then
        clear_stack()
      end
    end,
  })
end

return M
