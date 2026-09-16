------------------
-- CSS colour parsing and formatting.
--
-- Everything is carried as gamma-encoded sRGB in 0..1 plus alpha, because that
-- is the space every CSS notation here ultimately refers to. Conversions in and
-- out of OKLab go through linear-light sRGB and Björn Ottosson's matrices; the
-- constants below are his, not a re-derivation.
--
-- Output is CSS Color 4 syntax: space-separated components, `/ alpha` only when
-- the colour is not opaque, and percentages for the lightness of oklch/oklab as
-- the spec's own examples write them.
--
-- Not handled, and each an easy addition: named colours (`rebeccapurple`), and
-- `lab()`/`lch()`, which unlike `oklab()`/`oklch()` are D50-referenced and so
-- need a chromatic adaptation this module deliberately does not carry.
------------------

local M = {}

------------------
-- Formatting helpers
------------------

-- Trailing zeroes make `oklch(57.6% 0.134 258.4)` read like generated output
-- rather than something you would type, so they go.
local function num(v, decimals)
  local s = string.format("%." .. (decimals or 3) .. "f", v)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  return s == "-0" and "0" or s
end

local function clamp(v, lo, hi)
  return math.min(math.max(v, lo or 0), hi or 1)
end

local function alpha_suffix(a)
  if a >= 1 then
    return ""
  end
  return " / " .. num(a * 100, 1) .. "%"
end

------------------
-- sRGB transfer function
------------------

local function to_linear(c)
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

local function to_gamma(c)
  if c <= 0.0031308 then
    return c * 12.92
  end
  return 1.055 * c ^ (1 / 2.4) - 0.055
end

------------------
-- OKLab
------------------

local function srgb_to_oklab(r, g, b)
  local lr, lg, lb = to_linear(r), to_linear(g), to_linear(b)
  local l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
  local m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
  local s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
  -- Real cube root: these are non-negative, but be explicit about sign anyway.
  local function cbrt(v)
    return v < 0 and -((-v) ^ (1 / 3)) or v ^ (1 / 3)
  end
  local l_, m_, s_ = cbrt(l), cbrt(m), cbrt(s)
  return 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
end

local function oklab_to_srgb(L, a, b)
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b
  local m_ = L - 0.1055613458 * a - 0.0638541728 * b
  local s_ = L - 0.0894841775 * a - 1.2914855480 * b
  local l, m, s = l_ ^ 3, m_ ^ 3, s_ ^ 3
  local lr = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  local lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  local lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  -- An OKLab colour can sit outside sRGB; clamping is the honest thing to do
  -- when the target notation cannot express it.
  return clamp(to_gamma(lr)), clamp(to_gamma(lg)), clamp(to_gamma(lb))
end

------------------
-- HSL / HWB
------------------

local function rgb_to_hue_chroma(r, g, b)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local d = max - min
  local h = 0
  if d > 0 then
    if max == r then
      h = ((g - b) / d) % 6
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h * 60
  end
  return (h + 360) % 360, d, max, min
end

-- Pure hue at full chroma, as sRGB 0..1. This is the CSS Color 4 HSL→RGB
-- helper evaluated at s=1, l=0.5; the `(n + h/30) mod 12` indexing with
-- channels read off at 0, 8 and 4 is the spec's own, and is easy to get subtly
-- wrong -- a rolled-by-hand version reversed red and blue.
local function hue_to_rgb(h)
  h = h % 360
  local function f(n)
    local k = (n + h / 30) % 12
    return 0.5 - 0.5 * math.max(-1, math.min(k - 3, 9 - k, 1))
  end
  return f(0), f(8), f(4)
end

------------------
-- Parsing
------------------

-- Pull the numeric arguments out of `name(...)`, remembering which were
-- percentages, and split off an alpha given as `/ a`.
local function args_of(text, name)
  local inner = text:match("^" .. name .. "%(%s*(.-)%s*%)$")
  if not inner then
    return nil
  end
  local main, alpha = inner:match("^(.-)%s*/%s*(.+)$")
  main = main or inner
  local out = {}
  for tok in main:gmatch("[^%s,]+") do
    local n = tonumber((tok:gsub("[%%a-zA-Z]+$", "")))
    if not n then
      return nil
    end
    table.insert(out, { value = n, pct = tok:find("%%") ~= nil })
  end
  local a = 1
  if alpha then
    local n = tonumber((alpha:gsub("[%%a-zA-Z]+$", "")))
    if not n then
      return nil
    end
    a = alpha:find("%%") and n / 100 or n
  end
  return out, a
end

--- Parse any supported CSS colour notation.
--- @return table|nil `{ r, g, b, a }`, all 0..1, r/g/b gamma-encoded sRGB
function M.parse(text)
  text = vim.trim(text):lower()

  local hex = text:match("^#(%x+)$")
  if hex then
    local function pair(i)
      return tonumber(hex:sub(i, i + 1), 16) / 255
    end
    local function single(i)
      return tonumber(hex:sub(i, i):rep(2), 16) / 255
    end
    if #hex == 3 then
      return { r = single(1), g = single(2), b = single(3), a = 1 }
    elseif #hex == 4 then
      return { r = single(1), g = single(2), b = single(3), a = single(4) }
    elseif #hex == 6 then
      return { r = pair(1), g = pair(3), b = pair(5), a = 1 }
    elseif #hex == 8 then
      return { r = pair(1), g = pair(3), b = pair(5), a = pair(7) }
    end
    return nil
  end

  for _, name in ipairs({ "rgba", "rgb" }) do
    local v, a = args_of(text, name)
    if v and #v >= 3 then
      local function chan(c)
        return clamp(c.pct and c.value / 100 or c.value / 255)
      end
      -- Legacy `rgba(r, g, b, a)` puts alpha in the fourth slot instead.
      if #v == 4 then
        a = v[4].pct and v[4].value / 100 or v[4].value
      end
      return { r = chan(v[1]), g = chan(v[2]), b = chan(v[3]), a = clamp(a) }
    end
  end

  for _, name in ipairs({ "hsla", "hsl" }) do
    local v, a = args_of(text, name)
    if v and #v >= 3 then
      if #v == 4 then
        a = v[4].pct and v[4].value / 100 or v[4].value
      end
      local h = v[1].value
      local s = clamp(v[2].pct and v[2].value / 100 or v[2].value)
      local l = clamp(v[3].pct and v[3].value / 100 or v[3].value)
      local pr, pg, pb = hue_to_rgb(h)
      local c = (1 - math.abs(2 * l - 1)) * s
      local function mix(p)
        return l - c / 2 + c * p
      end
      return { r = clamp(mix(pr)), g = clamp(mix(pg)), b = clamp(mix(pb)), a = clamp(a) }
    end
  end

  do
    local v, a = args_of(text, "hwb")
    if v and #v >= 3 then
      local h = v[1].value
      local w = clamp(v[2].pct and v[2].value / 100 or v[2].value)
      local bl = clamp(v[3].pct and v[3].value / 100 or v[3].value)
      if w + bl >= 1 then
        local grey = w / (w + bl)
        return { r = grey, g = grey, b = grey, a = clamp(a) }
      end
      local pr, pg, pb = hue_to_rgb(h)
      local function mix(p)
        return p * (1 - w - bl) + w
      end
      return { r = clamp(mix(pr)), g = clamp(mix(pg)), b = clamp(mix(pb)), a = clamp(a) }
    end
  end

  do
    local v, a = args_of(text, "oklch")
    if v and #v >= 3 then
      local L = v[1].pct and v[1].value / 100 or v[1].value
      -- Chroma as a percentage is relative to 0.4, per CSS Color 4.
      local C = v[2].pct and v[2].value / 100 * 0.4 or v[2].value
      local h = math.rad(v[3].value)
      local r, g, b = oklab_to_srgb(L, C * math.cos(h), C * math.sin(h))
      return { r = r, g = g, b = b, a = clamp(a) }
    end
  end

  do
    local v, a = args_of(text, "oklab")
    if v and #v >= 3 then
      local L = v[1].pct and v[1].value / 100 or v[1].value
      local aa = v[2].pct and v[2].value / 100 * 0.4 or v[2].value
      local bb = v[3].pct and v[3].value / 100 * 0.4 or v[3].value
      local r, g, b = oklab_to_srgb(L, aa, bb)
      return { r = r, g = g, b = b, a = clamp(a) }
    end
  end

  return nil
end

------------------
-- Formatting
------------------

function M.to_hex(c)
  local function byte(v)
    return math.floor(clamp(v) * 255 + 0.5)
  end
  local s = string.format("#%02x%02x%02x", byte(c.r), byte(c.g), byte(c.b))
  if c.a < 1 then
    s = s .. string.format("%02x", byte(c.a))
  end
  return s
end

function M.to_rgb(c)
  local function byte(v)
    return math.floor(clamp(v) * 255 + 0.5)
  end
  return string.format("rgb(%d %d %d%s)", byte(c.r), byte(c.g), byte(c.b), alpha_suffix(c.a))
end

function M.to_hsl(c)
  local h, d, max, min = rgb_to_hue_chroma(c.r, c.g, c.b)
  local l = (max + min) / 2
  local s = 0
  if d > 0 and l > 0 and l < 1 then
    s = d / (1 - math.abs(2 * l - 1))
  end
  return string.format("hsl(%s %s%% %s%%%s)", num(h, 2), num(s * 100, 2), num(l * 100, 2), alpha_suffix(c.a))
end

function M.to_hwb(c)
  local h = rgb_to_hue_chroma(c.r, c.g, c.b)
  local w = math.min(c.r, c.g, c.b)
  local bl = 1 - math.max(c.r, c.g, c.b)
  return string.format("hwb(%s %s%% %s%%%s)", num(h, 2), num(w * 100, 2), num(bl * 100, 2), alpha_suffix(c.a))
end

function M.to_oklab(c)
  local L, a, b = srgb_to_oklab(c.r, c.g, c.b)
  return string.format("oklab(%s%% %s %s%s)", num(L * 100, 2), num(a, 4), num(b, 4), alpha_suffix(c.a))
end

function M.to_oklch(c)
  local L, a, b = srgb_to_oklab(c.r, c.g, c.b)
  local C = math.sqrt(a * a + b * b)
  local h = math.deg(math.atan2 and math.atan2(b, a) or math.atan(b, a))
  if h < 0 then
    h = h + 360
  end
  -- A greyscale colour has no meaningful hue; CSS writes that as 0.
  if C < 1e-6 then
    h, C = 0, 0
  end
  return string.format("oklch(%s%% %s %s%s)", num(L * 100, 2), num(C, 4), num(h, 2), alpha_suffix(c.a))
end

M.formats = {
  { name = "hex", fn = M.to_hex },
  { name = "rgb()", fn = M.to_rgb },
  { name = "hsl()", fn = M.to_hsl },
  { name = "hwb()", fn = M.to_hwb },
  { name = "oklch()", fn = M.to_oklch },
  { name = "oklab()", fn = M.to_oklab },
}

return M
