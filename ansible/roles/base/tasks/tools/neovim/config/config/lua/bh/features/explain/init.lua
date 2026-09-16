------------------
-- Explain the opaque literal under the cursor.
--
-- LSP hover (`K`) explains *symbols*. This is the other half: strings that are
-- meaningless as text but encode real structure -- a cron expression, a hex
-- colour, a base64 blob, a JWT, an epoch timestamp. The alternative is pasting
-- them into a website, which is exactly the kind of context switch worth
-- deleting.
--
-- Every decoder that recognises the text contributes a section, so an ambiguous
-- literal (`404` is both an HTTP status and a plausible file mode) reports both
-- rather than guessing. Nothing here shells out or needs a plugin: `vim.base64`
-- is built in, and the rest is string work.
--
-- Each decoder lives in decoders/ and is a function `(text) -> lines, value?`
-- returning nil when it does not recognise the input. To add one, drop a file
-- in there and add a line to the registry below; the order there is only the
-- order of sections in the float.
------------------

local M = {}

local SWATCH = require("bh.features.explain.util").SWATCH

------------------
-- Decoder registry
------------------

local decoders = {}
for _, name in ipairs({
  "cron",
  "colour",
  "jwt",
  "timestamp",
  "uuid",
  "http",
  "filemode",
  "number",
  "percent",
  "base64",
}) do
  table.insert(decoders, { name = name, run = require("bh.features.explain.decoders." .. name) })
end

------------------
-- What to look at
------------------

-- A cron expression has spaces in it, a hex colour starts with `#`, and a JWT
-- is full of dots -- none of which `<cword>` survives. So gather several
-- readings of "the thing under the cursor" and try them all.
local function candidates()
  local out, seen = {}, {}
  local function add(s)
    if type(s) ~= "string" then
      return
    end
    s = vim.trim(s)
    if s ~= "" and not seen[s] then
      seen[s] = true
      table.insert(out, s)
    end
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode:match("^[vV\22]") then
    local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
    if ok and region then
      add(table.concat(region, "\n"))
    end
    return out
  end

  -- The enclosing string literal, via treesitter. This is what catches a cron
  -- expression sitting inside `[Cron("0 */4 * * 1-5")]` or a JSON value.
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    local n = node
    for _ = 1, 4 do
      if not n then
        break
      end
      if n:type():match("string") then
        local ok_text, text = pcall(vim.treesitter.get_node_text, n, 0)
        if ok_text then
          add((text:gsub("^['\"`]", ""):gsub("['\"`]$", "")))
        end
        break
      end
      n = n:parent()
    end
  end

  -- Treesitter is not always there -- no parser for the filetype, a scratch
  -- buffer, a config file. Scanning the line for a quoted span or a `name(...)`
  -- call around the cursor recovers the same two shapes without it, and those
  -- are exactly the ones that contain spaces: `"0 */4 * * 1-5"`, `rgb(1, 2, 3)`.
  local line = vim.api.nvim_get_current_line()
  local cur = vim.api.nvim_win_get_cursor(0)[2] + 1
  local function spans(pat, strip)
    local init = 1
    while true do
      local a, b = line:find(pat, init)
      if not a then
        return
      end
      if cur >= a and cur <= b then
        add(strip and line:sub(a + 1, b - 1) or line:sub(a, b))
      end
      init = b + 1
    end
  end
  for _, q in ipairs({ '"', "'", "`" }) do
    spans(q .. "[^" .. q .. "]*" .. q, true)
  end
  spans("%a[%w_]*%b()", false)

  local word = vim.fn.expand("<cWORD>")
  add(word)
  -- Trailing punctuation from the surrounding code (`#fff",`) would otherwise
  -- defeat every anchored pattern.
  add((word:gsub("^[%(%[{<'\"`]+", ""):gsub("[%)%]}>,;:'\"`]+$", "")))
  add(vim.fn.expand("<cword>"))
  return out
end

------------------
-- Entry point
------------------

function M.explain()
  -- Candidates run widest-first, and the first one that any decoder recognises
  -- wins outright. Without that, a narrower reading of the same text gets
  -- decoded too: the `215` inside `hsl(215 67% 54%)` is a valid HTTP status and
  -- a valid file mode, so the colour would arrive with two bogus sections
  -- stapled to it. Ambiguity *within* one candidate is still reported in full,
  -- which is the case worth showing -- `404` really is both.
  local found = {}
  local primary
  for _, text in ipairs(candidates()) do
    for _, d in ipairs(decoders) do
      local ok, lines, value = pcall(d.run, text)
      if ok and lines then
        found[d.name] = lines
        table.insert(found, d.name)
        primary = primary or value
      end
    end
    if #found > 0 then
      break
    end
  end

  if #found == 0 then
    vim.notify("Nothing to explain here", vim.log.levels.INFO, { title = "explain" })
    return
  end

  local lines, colour_rows = {}, {}
  for i, name in ipairs(found) do
    if i > 1 then
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 40))
      table.insert(lines, "")
    end
    for _, l in ipairs(found[name]) do
      if name == "colour" and l:sub(1, #SWATCH) == SWATCH then
        colour_rows[#lines + 1] = l:match("^" .. SWATCH .. "%s+Colour%s+(.+)$")
      end
      table.insert(lines, l)
    end
  end

  local buf, win = vim.lsp.util.open_floating_preview(lines, "", {
    border = "rounded",
    max_width = 84,
    focus_id = "bh-explain",
    title = " explain ",
  })

  -- Paint the swatch with the colour it actually describes. This is why the
  -- decoder emits a literal block of characters rather than virtual text: it
  -- has to be real buffer text for an extmark to sit on it.
  local ns = vim.api.nvim_create_namespace("bh_explain")
  for row, spec in pairs(colour_rows) do
    -- Re-parse rather than carry the value along: whatever notation the user
    -- wrote, bh/colour.lua is the one thing that knows how to read it.
    local c = require("bh.lib.colour").parse(spec)
    if c then
      local hex = require("bh.lib.colour").to_hex(c):sub(1, 7)
      local group = "BhExplainSwatch" .. hex:sub(2)
      vim.api.nvim_set_hl(0, group, { fg = hex })
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, 0, {
        end_col = #SWATCH,
        hl_group = group,
      })
    end
  end

  -- The whole point of decoding a base64 blob is usually to then use the
  -- result, so make it one keypress away.
  if primary then
    vim.keymap.set("n", "y", function()
      vim.fn.setreg(vim.v.register or '"', primary)
      vim.fn.setreg("+", primary)
      vim.notify("Yanked decoded value", vim.log.levels.INFO, { title = "explain" })
      pcall(vim.api.nvim_win_close, win, true)
    end, { buffer = buf, desc = "Yank decoded value" })
  end

  return buf, win
end

return M
