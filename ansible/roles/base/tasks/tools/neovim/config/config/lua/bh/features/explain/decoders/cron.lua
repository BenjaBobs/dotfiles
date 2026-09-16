------------------
-- Cron expressions.
--
-- The largest decoder here by some way, because a cron string is the one input
-- that is genuinely a small language: five or six fields, each with its own
-- range, names, lists and steps -- plus the day-matching rule that is not the
-- AND everyone expects.
------------------

local sorted_keys = require("bh.features.explain.util").sorted_keys

local MONTHS =
  { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12 }
local DAYS = { sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6 }
local DAY_NAME = { [0] = "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTH_NAME = {
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
}

-- Expand one cron field into the set of values it matches, or nil if the field
-- is not valid cron. Returns the set plus whether the field was unrestricted
-- (`*` or `?`), which day-of-month/day-of-week matching depends on.
local function expand_field(spec, min, max, names)
  local set, wild = {}, false
  if spec == "*" or spec == "?" then
    wild = true
  end
  for part in spec:gmatch("[^,]+") do
    local body, step = part:match("^(.-)/(%d+)$")
    body = body or part
    step = tonumber(step) or 1
    if step < 1 then
      return nil
    end
    local lo, hi
    if body == "*" or body == "?" then
      lo, hi = min, max
    else
      local a, b = body:match("^(%w+)%-(%w+)$")
      if a then
        lo = tonumber(a) or (names and names[a:lower()])
        hi = tonumber(b) or (names and names[b:lower()])
      else
        lo = tonumber(body) or (names and names[body:lower()])
        hi = lo
      end
    end
    if not lo or not hi then
      return nil
    end
    if lo < min or hi > max or lo > hi then
      return nil
    end
    for v = lo, hi, step do
      set[v] = true
    end
  end
  if not next(set) then
    return nil
  end
  return set, wild
end

local function describe_field(set, wild, min, max, render, unit)
  local every = "every " .. unit
  if wild then
    return every
  end
  local vals = sorted_keys(set)
  local total = max - min + 1
  if #vals == total then
    return every
  end
  -- Detect a plain step so `*/15` reads as a step rather than four numbers.
  if #vals > 2 then
    local gap = vals[2] - vals[1]
    local even = true
    for i = 3, #vals do
      if vals[i] - vals[i - 1] ~= gap then
        even = false
        break
      end
    end
    if even and vals[1] == min and #vals > 3 then
      return string.format("every %d %ss (%s)", gap, unit, table.concat(vim.tbl_map(render, vals), ", "))
    end
  end
  return table.concat(vim.tbl_map(render, vals), ", ")
end

local function decode_cron(text)
  local fields = vim.split(vim.trim(text), "%s+", { trimempty = true })
  local secs
  if #fields == 6 then
    -- Quartz / .NET style puts seconds first. A 6th trailing *year* field also
    -- exists in the wild; seconds-first is the one C# schedulers emit.
    secs = table.remove(fields, 1)
  elseif #fields ~= 5 then
    return nil
  end

  local minute, minute_w = expand_field(fields[1], 0, 59)
  local hour, hour_w = expand_field(fields[2], 0, 23)
  local dom, dom_w = expand_field(fields[3], 1, 31)
  local month, month_w = expand_field(fields[4], 1, 12, MONTHS)
  local dow, dow_w = expand_field(fields[5], 0, 7, DAYS)
  if not (minute and hour and dom and month and dow) then
    return nil
  end
  local sec_set
  if secs then
    sec_set = expand_field(secs, 0, 59)
    if not sec_set then
      return nil
    end
  end
  -- Cron allows 7 for Sunday as well as 0; normalise so matching is simple.
  if dow[7] then
    dow[0] = true
  end

  local two = function(v)
    return string.format("%02d", v)
  end
  local lines = {
    "Cron  " .. vim.trim(text),
    "",
  }
  if secs then
    table.insert(lines, "second        " .. describe_field(sec_set, false, 0, 59, tostring, "second"))
  end
  vim.list_extend(lines, {
    "minute        " .. describe_field(minute, minute_w, 0, 59, tostring, "minute"),
    "hour          " .. describe_field(hour, hour_w, 0, 23, two, "hour"),
    "day of month  " .. describe_field(dom, dom_w, 1, 31, tostring, "day"),
    "month         " .. describe_field(month, month_w, 1, 12, function(v)
      return MONTH_NAME[v]
    end, "month"),
    "day of week   " .. describe_field(dow, dow_w, 0, 7, function(v)
      return DAY_NAME[v % 7]
    end, "day of the week"),
  })

  -- Day matching in cron is famously not a plain AND: when *both* day-of-month
  -- and day-of-week are restricted the two are OR'd, so `0 0 1 * MON` fires on
  -- the 1st *and* on every Monday. When either is `*` it behaves as an AND.
  local function day_matches(t)
    if not month[t.month] then
      return false
    end
    local wd = t.wday - 1 -- os.date wday is 1..7 starting Sunday
    if dom_w and dow_w then
      return true
    elseif dom_w then
      return dow[wd] == true
    elseif dow_w then
      return dom[t.day] == true
    else
      return dom[t.day] == true or dow[wd] == true
    end
  end

  -- Next fire times. Stepping day-by-day and only then walking that day's
  -- hours and minutes keeps this at ~366 + 1440 iterations worst case, instead
  -- of the half-million a naive minute-by-minute scan would need.
  local now = os.time()
  local hours, minutes = sorted_keys(hour), sorted_keys(minute)
  local upcoming = {}
  local probe = os.date("*t", now)
  probe.hour, probe.min, probe.sec = 12, 0, 0
  local base = os.time(probe)
  for d = 0, 366 do
    local t = os.date("*t", base + d * 86400)
    if day_matches(t) then
      for _, hh in ipairs(hours) do
        for _, mm in ipairs(minutes) do
          local ts = os.time({ year = t.year, month = t.month, day = t.day, hour = hh, min = mm, sec = 0 })
          if ts and ts > now then
            table.insert(upcoming, ts)
            if #upcoming >= 5 then
              goto done
            end
          end
        end
      end
    end
  end
  ::done::

  if #upcoming > 0 then
    table.insert(lines, "")
    table.insert(lines, "next")
    for _, ts in ipairs(upcoming) do
      table.insert(lines, "  " .. os.date("%a %Y-%m-%d %H:%M", ts))
    end
  end
  return lines
end

return decode_cron
