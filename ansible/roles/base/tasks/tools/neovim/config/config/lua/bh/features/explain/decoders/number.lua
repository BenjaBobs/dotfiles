------------------
-- Numbers in other bases.
------------------

local function decode_number(text)
  local n, base, label
  if text:match("^0[xX]%x+$") then
    n, base, label = tonumber(text:sub(3), 16), 16, "hex"
  elseif text:match("^0[bB][01]+$") then
    n, base, label = tonumber(text:sub(3), 2), 2, "binary"
  else
    return nil
  end
  if not n then
    return nil
  end
  local bits = ""
  local v = n
  repeat
    bits = (v % 2) .. bits
    v = math.floor(v / 2)
  until v == 0
  return {
    "Number (" .. label .. ", base " .. base .. ")",
    "",
    "decimal  " .. n,
    "hex      0x" .. string.format("%x", n),
    "binary   0b" .. bits,
    "octal    0o" .. string.format("%o", n),
  }
end

return decode_number
