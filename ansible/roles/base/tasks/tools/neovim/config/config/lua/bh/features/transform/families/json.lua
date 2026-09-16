------------------
-- JSON: shape and string escaping.
--
-- `jq` rather than a round-trip through `vim.json`: Lua tables are unordered,
-- so decoding and re-encoding an object silently reshuffles its keys.
------------------

local u = require("bh.features.transform.util")

return {
  {
    name = "JSON pretty-print",
    ft = "json",
    supported = u.is_json,
    run = function(t)
      return u.sh({ "jq", "." }, t)
    end,
  },

  {
    name = "JSON minify",
    ft = "json",
    supported = u.is_json,
    run = function(t)
      return u.sh({ "jq", "-c", "." }, t)
    end,
  },

  {
    name = "Escape as JSON string",
    universal = true,
    ft = "json",
    run = function(t)
      return vim.json.encode(t)
    end,
  },

  {
    name = "Unescape JSON string",
    ft = "text",
    supported = '^%s*".*"%s*$',
    run = function(t)
      local ok, v = pcall(vim.json.decode, vim.trim(t))
      return (ok and type(v) == "string") and v or nil
    end,
  },
}
