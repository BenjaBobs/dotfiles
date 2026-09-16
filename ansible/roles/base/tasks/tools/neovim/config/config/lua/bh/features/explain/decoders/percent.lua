------------------
-- URL percent-encoding.
------------------

local wrap = require("bh.features.explain.util").wrap

local function decode_percent(text)
  if not text:match("%%%x%x") then
    return nil
  end
  local out = text:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  if out == text then
    return nil
  end
  local lines = { "URL-encoded, decodes to:", "" }
  vim.list_extend(lines, wrap(out))
  return lines, out
end

return decode_percent
