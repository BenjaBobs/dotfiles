------------------
-- The transforms `<leader>ct` offers.
--
-- This file is only an ordered index; each family declares itself in its own
-- file under families/, and the engine in init.lua never needs touching to add
-- one. To add a family, create families/<name>.lua returning a list of entries
-- and add one line below. The order here is the order of the picker rows,
-- within the specific/universal split the engine applies.
--
-- To add a transform, append an entry:
--
--   {
--     name = "ROT13",        -- what the picker row says
--     ft = "text",           -- filetype for preview syntax highlighting
--     supported = "%a",      -- optional: when this transform applies
--     run = function(text)   -- return the result, or nil if it doesn't apply
--       return (text:gsub("%a", rot))
--     end,
--   }
--
-- Two rules, and they are the whole contract:
--
--   * `run` returns nil to mean "not applicable to this input". Anything that
--     returns nil, errors, returns "" or returns the text unchanged is dropped
--     before the picker opens -- so the list only ever shows transforms that
--     would really do something. Detection and execution are the same code
--     path, which is why there is no separate `detect` to keep in sync.
--   * `run` must be cheap enough to execute on every open, because all of them
--     run up front to build the previews.
--
-- Optional fields:
--
--   * `supported` -- when this transform applies. A predicate function taking
--     the text, or -- as sugar for the common case where that is purely a
--     question of the text's shape -- a Lua pattern, or a list of patterns that
--     must all match. It runs before `run`, so a transform that shells out
--     never pays for input it was always going to decline.
--
--     The function form is worth reaching for whenever the answer is not one
--     pattern: `supported = u.is_json` is a bare reference to an existing
--     helper, and a negative condition is just `not` rather than a second
--     field. `run` can still return nil for whatever cannot be known up front.
--   * `universal = true` marks a transform that applies to literally any text
--     (you can base64-encode anything). Those sort below the ones that had to
--     recognise something about the input, so the top of the picker is whatever
--     is actually specific to what you selected.
--
-- util.lua carries the shared bits: `sh` for piping through an external tool,
-- `tool`/`python_module` for gating on one, plus `printable`, `b64_decode` and
-- `is_json`. A transform whose tool is missing simply never appears.
------------------

local families = {
  "base64",
  "url_hex",
  "json",
  "yaml",
  "colour",
  "math",
  "jwt",
  "case",
}

local transforms = {}
for _, name in ipairs(families) do
  vim.list_extend(transforms, require("bh.features.transform.families." .. name))
end

return transforms
