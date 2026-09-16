------------------
-- UUIDs.
------------------

local function decode_uuid(text)
  local u = text:lower():match("^(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
  if not u then
    return nil
  end
  local ver = tonumber(u:sub(15, 15), 16)
  local variant_nibble = tonumber(u:sub(20, 20), 16)
  local variant = "reserved"
  if variant_nibble >= 8 and variant_nibble <= 11 then
    variant = "RFC 4122"
  elseif variant_nibble <= 7 then
    variant = "NCS (legacy)"
  elseif variant_nibble >= 12 and variant_nibble <= 13 then
    variant = "Microsoft GUID"
  end
  local kinds = {
    [1] = "time-based",
    [2] = "DCE security",
    [3] = "MD5 name-based",
    [4] = "random",
    [5] = "SHA-1 name-based",
    [6] = "reordered time",
    [7] = "Unix-epoch time",
  }
  local lines =
    { "UUID", "", "version  " .. ver .. (kinds[ver] and ("  (" .. kinds[ver] .. ")") or ""), "variant  " .. variant }
  if ver == 7 then
    local ms = tonumber(u:sub(1, 8) .. u:sub(10, 13), 16)
    table.insert(lines, "time     " .. os.date("%Y-%m-%d %H:%M:%S", math.floor(ms / 1000)))
  end
  if u == "00000000-0000-0000-0000-000000000000" then
    table.insert(lines, "")
    table.insert(lines, "This is the nil UUID (all zeroes).")
  end
  return lines
end

return decode_uuid
