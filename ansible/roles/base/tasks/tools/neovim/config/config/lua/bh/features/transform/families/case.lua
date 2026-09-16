------------------
-- Case conversions.
--
-- Borrowed from text-case.nvim rather than reimplemented, so these agree
-- exactly with the `<leader>cc` picker -- `.apply` is the same pure function
-- that keymap ends up calling. If the plugin is missing they simply do not
-- appear, like any other unavailable tool.
--
-- The only input these genuinely cannot handle is a multi-line one, where
-- text-case flattens `"a\nb"` into `"a_b"` and silently eats your line breaks.
-- Rather than hide the rows for that case, `map_lines` applies the conversion
-- per line -- so casing a selected column of property names works, which is
-- most of why you would select more than one line in the first place.
--
-- Beyond that they are offered whenever the text contains a letter at all. With
-- no letter there is nothing to case, and the engine's no-op rule already drops
-- any conversion whose output equals its input.
------------------

local u = require("bh.features.transform.util")

local out = {}

for _, method in ipairs({
  { "to_snake_case", "to_snake_case" },
  { "to_camel_case", "toCamelCase" },
  { "to_pascal_case", "ToPascalCase" },
  { "to_dash_case", "to-dash-case" },
  { "to_constant_case", "TO_CONSTANT_CASE" },
  { "to_title_case", "To Title Case" },
  { "to_dot_case", "to.dot.case" },
  { "to_path_case", "to/path/case" },
  { "to_phrase_case", "To phrase case" },
  { "to_upper_case", "TO UPPER CASE" },
  { "to_lower_case", "to lower case" },
}) do
  local fn, label = method[1], method[2]
  table.insert(out, {
    name = "case: " .. label,
    ft = "text",
    supported = "%a",
    run = function(t)
      local ok, api = pcall(function()
        return require("textcase").api
      end)
      if not ok or not api[fn] then
        return nil
      end
      return u.map_lines(t, api[fn].apply)
    end,
  })
end

return out
