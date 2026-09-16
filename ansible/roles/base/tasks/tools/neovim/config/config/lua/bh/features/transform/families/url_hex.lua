------------------
-- Percent-encoding and raw hex bytes.
------------------

local u = require("bh.features.transform.util")

return {
  {
    name = "URL encode",
    universal = true,
    ft = "text",
    run = function(t)
      return (t:gsub("[^%w%-%._~]", function(c)
        return string.format("%%%02X", c:byte())
      end))
    end,
  },

  {
    name = "URL decode",
    ft = "text",
    supported = "%%%x%x",
    run = function(t)
      return (t:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
      end))
    end,
  },

  {
    name = "Hex encode",
    universal = true,
    ft = "text",
    run = function(t)
      return (t:gsub(".", function(c)
        return string.format("%02x", c:byte())
      end))
    end,
  },

  {
    name = "Hex decode",
    ft = "text",
    -- Not one pattern: an even count of hex digits and nothing else.
    supported = function(t)
      local s = t:gsub("%s", "")
      return #s >= 2 and #s % 2 == 0 and not s:find("%X")
    end,
    run = function(t)
      local s = t:gsub("%s", "")
      local d = s:gsub("%x%x", function(h)
        return string.char(tonumber(h, 16))
      end)
      return u.printable(d) and d or nil
    end,
  },
}
