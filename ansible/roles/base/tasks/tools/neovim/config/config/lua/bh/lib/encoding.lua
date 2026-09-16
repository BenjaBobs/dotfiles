------------------
-- Encoding primitives shared by bh/explain.lua (which reads encoded values)
-- and bh/transform/ (which rewrites them).
--
-- Small, but worth having in one place: both sides need to decide whether a
-- decode produced text or noise, and both need base64 that tolerates the
-- base64url alphabet and missing padding. Two copies had already drifted --
-- one always normalised base64url, the other took a flag.
------------------

local M = {}

--- Is this mostly text? Decoders use it to avoid presenting binary noise as a
--- successful decode.
function M.printable(s)
  if s == "" then
    return false
  end
  local bad = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 9 or (b > 13 and b < 32) or b == 127 then
      bad = bad + 1
    end
  end
  return bad / #s < 0.1
end

--- Base64 decode. With `url`, first maps the base64url alphabet (`-`/`_`) back
--- to standard; padding may be absent either way, as JWTs and most URL-safe
--- encoders omit it.
--- @return string|nil
function M.b64_decode(s, url)
  local norm = url and (s:gsub("-", "+"):gsub("_", "/")) or s
  local pad = #norm % 4
  if pad == 2 then
    norm = norm .. "=="
  elseif pad == 3 then
    norm = norm .. "="
  elseif pad == 1 then
    return nil
  end
  local ok, res = pcall(vim.base64.decode, norm)
  return ok and res or nil
end

return M
