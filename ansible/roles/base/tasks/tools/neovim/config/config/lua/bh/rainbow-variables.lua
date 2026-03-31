-- Rainbow variables: assigns each identifier a unique foreground color
-- based on a hash of its name. Colors are generated in OKLCH space with
-- fixed lightness/chroma and evenly distributed hues, skipping hue ranges
-- that overlap with Catppuccin Mocha syntax highlighting colors.

-- Generate palette by distributing evenly across allowed hues
-- Use golden angle (~137.5°) distribution for maximum perceptual spacing
-- even between adjacent indices, rather than sequential distribution.
local COLOR_COUNT = 16
local LIGHTNESS = 0.70
local CHROMA = 0.2

-- OKLCH → linear sRGB → sRGB hex conversion
-- Reference: https://bottosson.github.io/posts/oklab/

local function oklab_to_linear_srgb(L, a, b)
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b
  local m_ = L - 0.1055613458 * a - 0.0638541728 * b
  local s_ = L - 0.0894841775 * a - 1.2914855480 * b

  local l = l_ * l_ * l_
  local m = m_ * m_ * m_
  local s = s_ * s_ * s_

  return 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

local function oklch_to_hex(L, C, h_deg)
  local h_rad = h_deg * math.pi / 180
  local a = C * math.cos(h_rad)
  local b = C * math.sin(h_rad)
  local r, g, bl = oklab_to_linear_srgb(L, a, b)

  -- Linear sRGB to sRGB gamma
  local function gamma(x)
    if x <= 0.0031308 then
      return 12.92 * x
    end
    return 1.055 * math.pow(x, 1.0 / 2.4) - 0.055
  end

  r = math.max(0, math.min(1, gamma(r)))
  g = math.max(0, math.min(1, gamma(g)))
  bl = math.max(0, math.min(1, gamma(bl)))

  return string.format(
    "#%02x%02x%02x",
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(bl * 255 + 0.5)
  )
end

-- Catppuccin Mocha hue ranges to avoid (measured OKLCH hues, ±10° margin).
-- We use lower lightness (0.70) than Catppuccin (0.75-0.92) to add
-- further separation even when hues are nearby.
--   Red:        353-13   (H=2.8)
--   Maroon:     359-19   (H=8.8)
--   Peach:      43-63    (H=52.6)
--   Yellow:     77-97    (H=86.5)
--   Green:      133-153  (H=142.7)
--   Teal:       173-193  (H=182.7)
--   Sky:        200-220  (H=210.3)
--   Blue:       250-270  (H=259.9)
--   Lavender:   267-287  (H=277.3)
--   Mauve:      295-315  (H=304.8)
--   Pink:       326-346  (H=336.3)
local avoided_ranges = {
  { 353, 360 },
  { 0, 19 }, -- Red/Maroon
  { 43, 63 }, -- Peach
  { 77, 97 }, -- Yellow
  { 133, 153 }, -- Green
  { 173, 193 }, -- Teal
  { 200, 220 }, -- Sky
  { 250, 287 }, -- Blue/Lavender
  { 295, 315 }, -- Mauve
  { 326, 346 }, -- Pink
}

local function is_hue_avoided(h)
  for _, range in ipairs(avoided_ranges) do
    if h >= range[1] and h <= range[2] then
      return true
    end
  end
  return false
end

-- Collect allowed hue slots (1-degree resolution)
local allowed_hues = {}
for h = 0, 359 do
  if not is_hue_avoided(h) then
    table.insert(allowed_hues, h)
  end
end

local palette = {}
local golden_angle = 137.508
for i = 0, COLOR_COUNT - 1 do
  -- Golden angle ensures any two adjacent indices are far apart in hue
  local raw_hue = (i * golden_angle) % 360
  -- Find the closest allowed hue
  local best_dist = 360
  local best_hue = allowed_hues[1]
  for _, h in ipairs(allowed_hues) do
    local dist = math.min(math.abs(h - raw_hue), 360 - math.abs(h - raw_hue))
    if dist < best_dist then
      best_dist = dist
      best_hue = h
    end
  end
  table.insert(palette, oklch_to_hex(LIGHTNESS, CHROMA, best_hue))
end

-- Semantic token types to colorize
local token_types = {
  variable = true,
  parameter = true,
  property = true,
}

local function hash_name(name, count)
  -- djb2 hash — better distribution than simple polynomial
  local h = 5381
  for i = 1, #name do
    h = ((h * 33) + name:byte(i)) % 65536
  end
  return h % count
end

-- Create highlight groups
for i, color in ipairs(palette) do
  vim.api.nvim_set_hl(0, "RainbowVar" .. (i - 1), { fg = color })
end

-- Max file size (in bytes) for rainbow highlighting.
-- Beyond this, skip to avoid performance issues.
local MAX_FILE_SIZE = 100 * 1024 -- 100 KB

-- Cache of buffers we've already decided to skip
local skipped_bufs = {}

vim.api.nvim_create_autocmd("LspTokenUpdate", {
  callback = function(args)
    local buf = args.buf

    -- Check skip cache first (avoid repeated stat calls)
    if skipped_bufs[buf] then
      return
    end

    -- Check file size on first token for this buffer
    if skipped_bufs[buf] == nil then
      local fname = vim.api.nvim_buf_get_name(buf)
      if fname ~= "" then
        local stat = vim.uv.fs_stat(fname)
        if stat and stat.size > MAX_FILE_SIZE then
          skipped_bufs[buf] = true
          return
        end
      end
      skipped_bufs[buf] = false
    end

    local token = args.data.token
    if not token_types[token.type] then
      return
    end

    local line = vim.api.nvim_buf_get_lines(buf, token.line, token.line + 1, true)[1]
    if not line then
      return
    end

    local name = line:sub(token.start_col + 1, token.end_col)
    local color_id = hash_name(name, #palette)

    vim.lsp.semantic_tokens.highlight_token(token, buf, args.data.client_id, "RainbowVar" .. color_id)
  end,
})

-- Clean up cache when buffers are deleted
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    skipped_bufs[args.buf] = nil
  end,
})
