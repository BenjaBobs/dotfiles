------------------
-- Base64, standard and url-safe.
------------------

local u = require("bh.features.transform.util")

return {
  {
    name = "Base64 encode",
    universal = true,
    ft = "text",
    run = function(t)
      return vim.base64.encode(t)
    end,
  },

  {
    name = "Base64 decode",
    ft = "text",
    supported = "^[%w%+/]+=*$",
    run = function(t)
      local d = u.b64_decode(t, false)
      return (d and u.printable(d)) and d or nil
    end,
  },

  {
    name = "Base64url encode",
    universal = true,
    ft = "text",
    run = function(t)
      return (vim.base64.encode(t):gsub("%+", "-"):gsub("/", "_"):gsub("=", ""))
    end,
  },

  {
    name = "Base64url decode",
    ft = "text",
    supported = "^[%w%-_]+=*$",
    run = function(t)
      local d = u.b64_decode(t, true)
      return (d and u.printable(d)) and d or nil
    end,
  },
}
