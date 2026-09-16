------------------
-- Helpers for transform authors. Everything here is meant to be called from
-- `run` functions in catalog.lua; nothing in the engine depends on it.
------------------

local M = {}

local have = {}

--- Is an executable on PATH? Cached, so a missing tool costs one lookup.
function M.tool(name)
  if have[name] == nil then
    have[name] = vim.fn.executable(name) == 1
  end
  return have[name]
end

--- Run `cmd` with `stdin`, returning trimmed stdout, or nil if the tool is
--- missing or exited non-zero. Returning nil is also how a transform says
--- "I don't apply", so a missing tool removes its entries from the picker
--- instead of erroring.
function M.sh(cmd, stdin)
  if not M.tool(cmd[1]) then
    return nil
  end
  local ok, res = pcall(function()
    return vim.system(cmd, { stdin = stdin, text = true }):wait(5000)
  end)
  if not ok or res.code ~= 0 then
    return nil
  end
  return ((res.stdout or ""):gsub("\n$", ""))
end

--- Does `python3` have a given module? Use this to gate a transform on a
--- library rather than just the interpreter.
function M.python_module(name)
  local key = "py:" .. name
  if have[key] == nil then
    have[key] = M.tool("python3") and M.sh({ "python3", "-c", "import " .. name }, "") ~= nil
  end
  return have[key]
end

-- Re-exported from bh/encoding.lua so catalogue authors have one place to look;
-- the implementations are shared with bh/explain.lua.
M.printable = require("bh.lib.encoding").printable
M.b64_decode = require("bh.lib.encoding").b64_decode

--- Apply `fn` to each line and rejoin.
---
--- Case conversions need this: text-case flattens a multi-line string into one
--- line (`"a\nb"` becomes `"a_b"`), silently destroying the line structure.
--- Per-line application turns "unsupported" into "works on a column of names".
function M.map_lines(text, fn)
  local out = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    if line == "" then
      table.insert(out, "")
    else
      local ok, res = pcall(fn, line)
      if not ok then
        return nil
      end
      table.insert(out, res)
    end
  end
  return table.concat(out, "\n")
end

--- Does the text parse as a JSON object or array?
function M.is_json(text)
  local ok, v = pcall(vim.json.decode, text)
  return ok and type(v) == "table"
end

return M
