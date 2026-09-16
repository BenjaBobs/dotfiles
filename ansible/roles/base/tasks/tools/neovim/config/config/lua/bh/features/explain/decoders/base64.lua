------------------
-- Base64.
------------------

local printable = require("bh.lib.encoding").printable
local wrap = require("bh.features.explain.util").wrap
local b64_decode = require("bh.features.explain.util").b64_decode

local function decode_base64(text)
  -- Short strings are far more likely to be identifiers that happen to be
  -- base64-shaped than actual payloads, so require some length.
  if #text < 8 or not text:match("^[%w%+/%-_]+=*$") then
    return nil
  end
  local raw = b64_decode(text)
  if not raw or not printable(raw) then
    return nil
  end
  local lines = { "Base64 decodes to:", "" }
  vim.list_extend(lines, wrap(raw))
  return lines, raw
end

return decode_base64
