------------------
-- CSS colour notation.
--
-- One entry per notation, each offered whenever the input parses as a colour in
-- any of them -- so hex → oklch and oklch → rgb() are the same mechanism, and
-- the no-op rule drops the row for the notation you are already in.
-- bh/colour.lua carries the conversions, shared with bh/explain.
------------------

local out = {}

for _, format in ipairs(require("bh.lib.colour").formats) do
  table.insert(out, {
    name = "colour: " .. format.name,
    ft = "css",
    supported = function(t)
      return require("bh.lib.colour").parse(t) ~= nil
    end,
    run = function(t)
      local c = require("bh.lib.colour").parse(t)
      return c and format.fn(c) or nil
    end,
  })
end

return out
