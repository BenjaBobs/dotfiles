------------------
-- JSON Web Tokens.
------------------

local b64_decode = require("bh.features.explain.util").b64_decode

local function decode_jwt(text)
  local h, p, sig = text:match("^([%w%-_]+)%.([%w%-_]+)%.([%w%-_]*)$")
  if not h then
    return nil
  end
  local header, payload = b64_decode(h), b64_decode(p)
  if not header or not payload then
    return nil
  end
  local ok_h, hj = pcall(vim.json.decode, header)
  local ok_p, pj = pcall(vim.json.decode, payload)
  if not ok_h or not ok_p then
    return nil
  end
  local lines = { "JWT", "", "Header:" }
  vim.list_extend(lines, vim.split(vim.json.encode(hj), "\n"))
  table.insert(lines, "")
  table.insert(lines, "Payload:")
  vim.list_extend(lines, vim.split(vim.inspect(pj), "\n"))
  -- The registered time claims are epoch seconds, which is the whole reason a
  -- JWT is unreadable at a glance.
  for _, claim in ipairs({ "iat", "nbf", "exp" }) do
    if type(pj[claim]) == "number" then
      local when = os.date("%Y-%m-%d %H:%M:%S", pj[claim])
      local delta = pj[claim] - os.time()
      local rel = delta >= 0 and string.format("in %dm", math.floor(delta / 60))
        or string.format("%dm ago", math.floor(-delta / 60))
      table.insert(lines, string.format("%s  %s (%s)", claim, when, rel))
    end
  end
  table.insert(lines, "signature " .. (sig == "" and "(none)" or #sig .. " chars, not verified"))
  return lines
end

return decode_jwt
