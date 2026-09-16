------------------
-- JSON Web Tokens. Read-only: decoding a JWT here cannot re-sign it, so the
-- result is for inspection, not for pasting back as a valid token.
------------------

local u = require("bh.features.transform.util")

return {
  {
    name = "Decode JWT",
    ft = "json",
    supported = "^[%w%-_]+%.[%w%-_]+%.[%w%-_]*$",
    run = function(t)
      local h, p = t:match("^([%w%-_]+)%.([%w%-_]+)%.[%w%-_]*$")
      if not h then
        return nil
      end
      local hd, pd = u.b64_decode(h, true), u.b64_decode(p, true)
      if not (hd and pd) then
        return nil
      end
      return (u.sh({ "jq", "." }, hd) or hd) .. "\n" .. (u.sh({ "jq", "." }, pd) or pd)
    end,
  },
}
