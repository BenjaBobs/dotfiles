-- Respect a scroll margin even at the end of the buffer.
--
-- Neovim has no native "scroll beyond last line" setting, so at EOF the cursor
-- can sit on the very bottom row. This scrolls the view (no real lines added,
-- just empty space shown below) so the last lines are pulled up and a margin of
-- blank rows is kept below the cursor near EOF.
--
-- We hook WinScrolled as well as CursorMoved: a jump such as <C-d>/<C-End>
-- settles the view via a scroll, and only then are winline()/topline accurate.
-- A CursorMoved-only hook runs before the view settles and no-ops for jumps.
-- Assumes `wrap` is off (set in vim-vars).

-- How many blank rows to keep below the cursor at EOF, i.e. how far past the
-- last line you can scroll. `nil` follows `scrolloff`; set a number here (or
-- `vim.g.eof_scroll_lines` at runtime / in vim-vars) to decouple it. Values
-- above roughly (window height - scrolloff) saturate, since `scrolloff` keeps
-- the cursor from reaching the top of the window.
local DEFAULT_EOF_SCROLL_LINES = nil

local function eof_scroll_lines()
  local v = vim.g.eof_scroll_lines
  if v == nil then
    v = DEFAULT_EOF_SCROLL_LINES
  end
  if v == nil then
    v = vim.o.scrolloff
  end
  return v
end

local group = vim.api.nvim_create_augroup("bh_scroll_past_eof", { clear = true })

local function keep_scrolloff_at_eof(ev)
  local pad = eof_scroll_lines()
  if pad <= 0 then
    return
  end

  -- Leave floating windows (completion/preview/pickers) alone.
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end

  -- On WinScrolled, only react to a downward scroll of the current window; this
  -- avoids reacting to our own upward adjustment or to horizontal scrolls.
  if ev.event == "WinScrolled" then
    local w = vim.v.event[tostring(vim.api.nvim_get_current_win())]
    if w and w.topline <= 0 then
      return
    end
  end

  local win_height = vim.fn.winheight(0)
  pad = math.min(pad, win_height - 1)

  -- Only near EOF: if there is at least `pad` lines of real content below the
  -- cursor, Neovim's own scrolloff handles the margin and we stay out of it.
  if vim.fn.line("$") - vim.fn.line(".") >= pad then
    return
  end

  -- Add blank rows below until the cursor has `pad` rows beneath it.
  local rows_below = win_height - vim.fn.winline()
  if rows_below < pad then
    local view = vim.fn.winsaveview()
    vim.fn.winrestview({
      skipcol = 0, -- avoids a cursor-column display glitch after gg/G
      topline = view.topline + (pad - rows_below),
    })
  end
end

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
  group = group,
  callback = keep_scrolloff_at_eof,
})
