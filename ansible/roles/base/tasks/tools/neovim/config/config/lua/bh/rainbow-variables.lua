-- Rainbow variables: assign each identifier a stable foreground color
-- based on a hash of its name.
--
-- This uses semantic tokens from the LSP and maps identifier names into a
-- fixed palette generated in OKLCH space. The palette keeps lightness and
-- chroma constant, while varying hue, so colors feel consistent in strength.
--
-- Hues that overlap too much with Catppuccin Mocha's main syntax colors are
-- excluded so rainbow variables stand apart from normal highlighting.

local bit = require("bit")
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local tobit = bit.tobit

-- Number of distinct rainbow colors to generate.
local COLOR_COUNT = 61

-- Fixed OKLCH values for all rainbow colors.
local LIGHTNESS = 0.70
local CHROMA = 0.14

-- Maximum file size (in bytes) to apply rainbow highlighting to.
-- Larger files are skipped to avoid unnecessary work on frequent token updates.
local MAX_FILE_SIZE = 100 * 1024

-- Semantic token types to colorize.
local token_types = {
  variable = true,
  parameter = true,
  property = true,
}

-- Hue ranges to avoid so rainbow colors do not blend too much with the
-- colors already used by the Catppuccin Mocha theme.
local avoided_ranges = {
  { 353, 360 },
  { 0, 19 }, -- red / maroon
  { 43, 63 }, -- peach
  { 77, 97 }, -- yellow
  { 133, 153 }, -- green
  { 173, 193 }, -- teal
  { 200, 220 }, -- sky
  { 250, 287 }, -- blue / lavender
  { 295, 315 }, -- mauve
  { 326, 346 }, -- pink
}

-- Cache of buffers already classified as small enough or too large.
local skipped_bufs = {}

-- Convert OKLab to linear sRGB.
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

-- Convert OKLCH to an sRGB hex string.
local function oklch_to_hex(L, C, h_deg)
  local h_rad = h_deg * math.pi / 180
  local a = C * math.cos(h_rad)
  local b = C * math.sin(h_rad)
  local r, g, bl = oklab_to_linear_srgb(L, a, b)

  local function gamma(x)
    if x <= 0.0031308 then
      return 12.92 * x
    end
    return 1.055 * math.pow(x, 1 / 2.4) - 0.055
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

local function is_hue_avoided(h)
  for _, range in ipairs(avoided_ranges) do
    if h >= range[1] and h <= range[2] then
      return true
    end
  end
  return false
end

-- Collect all allowed hues at 1-degree resolution.
local allowed_hues = {}
for h = 0, 359 do
  if not is_hue_avoided(h) then
    table.insert(allowed_hues, h)
  end
end

-- Build the palette by sampling evenly across the allowed hue list.
-- This guarantees that each palette entry comes from a distinct allowed hue.
local palette = {}
for i = 0, COLOR_COUNT - 1 do
  local idx = math.floor(i * (#allowed_hues - 1) / math.max(COLOR_COUNT - 1, 1)) + 1
  palette[i + 1] = oklch_to_hex(LIGHTNESS, CHROMA, allowed_hues[idx])
end

-- Hash an identifier name into a stable 32-bit value.
-- The final color index is produced by reducing this hash modulo the palette size.
local function hash_name(name)
  local h = 0

  for i = 1, #name do
    h = tobit(h + name:byte(i))
    h = tobit(h + lshift(h, 10))
    h = bxor(h, rshift(h, 6))
  end

  h = tobit(h + lshift(h, 3))
  h = bxor(h, rshift(h, 11))
  h = tobit(h + lshift(h, 15))

  return h % 0x100000000
end

-- Create one highlight group per palette color.
for i, color in ipairs(palette) do
  vim.api.nvim_set_hl(0, "RainbowVar" .. (i - 1), { fg = color })
end

vim.api.nvim_create_autocmd("LspTokenUpdate", {
  callback = function(args)
    local buf = args.buf

    if skipped_bufs[buf] then
      return
    end

    -- Check file size once per buffer and cache the result.
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

    -- Read the exact token text from the buffer.
    local parts =
      vim.api.nvim_buf_get_text(buf, token.line, token.start_col, token.end_line or token.line, token.end_col, {})

    local name = table.concat(parts, "\n")
    if name == "" then
      return
    end

    local color_id = hash_name(name) % #palette

    vim.lsp.semantic_tokens.highlight_token(token, buf, args.data.client_id, "RainbowVar" .. color_id)
  end,
})

-- Clear cached size decisions when buffers are deleted.
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    skipped_bufs[args.buf] = nil
  end,
})
