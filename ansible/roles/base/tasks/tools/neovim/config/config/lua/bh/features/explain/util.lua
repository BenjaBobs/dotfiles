------------------
-- Shared bits for the explain decoders.
------------------

local M = {}

-- A literal run of block characters rather than virtual text: the swatch has to
-- be real buffer text for an extmark to sit on it and paint it.
M.SWATCH = "████"

function M.sorted_keys(set)
  local out = {}
  for k in pairs(set) do
    table.insert(out, k)
  end
  table.sort(out)
  return out
end

--- Wrap a long single-line value so the float stays a sane width.
function M.wrap(s, width)
  width = width or 76
  if #s <= width then
    return { s }
  end
  local out = {}
  for i = 1, #s, width do
    table.insert(out, s:sub(i, i + width - 1))
  end
  return out
end

--- Always url-tolerant: explain is looking at text someone wrote, and a JWT or
--- a URL-safe payload is as likely as standard base64.
function M.b64_decode(s)
  return require("bh.lib.encoding").b64_decode(s, true)
end

return M
