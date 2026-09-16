------------------
-- POSIX file modes.
------------------

local function decode_filemode(text)
  local oct = text:match("^0?([0-7][0-7][0-7])$")
  if not oct then
    return nil
  end
  local names = { "owner", "group", "other" }
  local lines = { "File mode " .. text, "" }
  local sym = ""
  for i = 1, 3 do
    local d = tonumber(oct:sub(i, i))
    local bits = (d >= 4 and "r" or "-") .. (d % 4 >= 2 and "w" or "-") .. (d % 2 == 1 and "x" or "-")
    sym = sym .. bits
    table.insert(lines, string.format("%-6s %s  %s", names[i], bits, d))
  end
  table.insert(lines, "")
  table.insert(lines, "symbolic  " .. sym)
  return lines, sym
end

return decode_filemode
