------------------
-- Colours.
--
-- Parsing and conversion live in bh/colour.lua, shared with the transform
-- picker: `gK` is the read-only view of exactly what `<leader>ct` can convert
-- between, so the two cannot disagree about what counts as a colour.
------------------

local SWATCH = require("bh.features.explain.util").SWATCH

local function decode_colour(text)
  local colour = require("bh.lib.colour")
  local c = colour.parse(text)
  if not c then
    return nil
  end

  -- Relative luminance, per WCAG. This is the part that is genuinely about
  -- *reading* a colour rather than rewriting it: "will black or white text
  -- show up on this?" is most of why you look one up in the first place.
  local function chan(v)
    return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end
  local lum = 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b)
  local on_white = 1.05 / (lum + 0.05)
  local on_black = (lum + 0.05) / 0.05

  local lines = { SWATCH .. "  Colour " .. vim.trim(text), "" }
  for _, format in ipairs(colour.formats) do
    table.insert(lines, string.format("%-7s %s", format.name, format.fn(c)))
  end
  table.insert(lines, "")
  table.insert(lines, string.format("text    %.1f:1 on white, %.1f:1 on black", on_white, on_black))
  return lines, colour.to_hex(c)
end

return decode_colour
