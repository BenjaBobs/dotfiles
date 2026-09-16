------------------
-- Unix timestamps.
------------------

local function decode_timestamp(text)
  local n = text:match("^(%d+)$")
  if not n then
    return nil
  end
  local secs
  if #n == 10 then
    secs = tonumber(n)
  elseif #n == 13 then
    secs = math.floor(tonumber(n) / 1000)
  else
    return nil
  end
  local delta = os.time() - secs
  local function human(d)
    local abs = math.abs(d)
    local unit, div = "second", 1
    for _, u in ipairs({ { "minute", 60 }, { "hour", 3600 }, { "day", 86400 }, { "year", 31557600 } }) do
      if abs >= u[2] then
        unit, div = u[1], u[2]
      end
    end
    return string.format("%.1f %ss %s", abs / div, unit, d >= 0 and "ago" or "from now")
  end
  return {
    "Unix timestamp (" .. (#n == 13 and "milliseconds" or "seconds") .. ")",
    "",
    "local  " .. os.date("%Y-%m-%d %H:%M:%S", secs),
    "UTC    " .. os.date("!%Y-%m-%d %H:%M:%S", secs),
    "rel    " .. human(delta),
  }
end

return decode_timestamp
