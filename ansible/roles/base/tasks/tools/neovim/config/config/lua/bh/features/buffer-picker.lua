local M = {}

local function is_pinned(buf)
  return vim.b[buf].bh_pinned == true
end

local function set_pinned(buf, pinned)
  vim.b[buf].bh_pinned = pinned and true or false
end

local function ensure_highlights()
  local info = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
  vim.api.nvim_set_hl(0, "BhPinnedBufferPin", {
    fg = info.fg,
    bold = true,
  })
end

local function selected_buffer_items(picker)
  local items = picker:selected({ fallback = true })
  return vim.tbl_filter(function(item)
    return item and item.buf and vim.api.nvim_buf_is_valid(item.buf)
  end, items)
end

local function toggle_pin(picker)
  local items = selected_buffer_items(picker)
  if vim.tbl_isempty(items) then
    return
  end

  for _, item in ipairs(items) do
    set_pinned(item.buf, not is_pinned(item.buf))
  end

  picker:refresh()
end

local function close_unpinned_buffers(picker)
  local current = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buflisted
      and not is_pinned(buf)
      and buf ~= current
    then
      Snacks.bufdelete.delete(buf)
    end
  end

  picker:refresh()
end

local function finder(opts, ctx)
  local items = require("snacks.picker.source.buffers").buffers(opts, ctx)
  for _, item in ipairs(items) do
    if item.buf and is_pinned(item.buf) then
      item.bh_pinned = true
    end
  end
  return items
end

local function format_buffer(item, picker)
  local ret = {}
  ret[#ret + 1] = { Snacks.picker.util.align(tostring(item.buf), 3), "SnacksPickerBufNr" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { item.bh_pinned and "󰐃" or " ", item.bh_pinned and "BhPinnedBufferPin" or "SnacksPickerBufFlags" }
  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { Snacks.picker.util.align(item.flags, 2, { align = "right" }), "SnacksPickerBufFlags" }
  ret[#ret + 1] = { " " }

  vim.list_extend(ret, Snacks.picker.format.filename(item, picker))

  if item.buftype ~= "" then
    ret[#ret + 1] = { " " }
    vim.list_extend(ret, {
      { "[", "SnacksPickerDelim" },
      { item.buftype, "SnacksPickerBufType" },
      { "]", "SnacksPickerDelim" },
    })
  end

  if item.name == "" and item.filetype ~= "" then
    ret[#ret + 1] = { " " }
    vim.list_extend(ret, {
      { "[", "SnacksPickerDelim" },
      { item.filetype, "SnacksPickerFileType" },
      { "]", "SnacksPickerDelim" },
    })
  end

  return ret
end

function M.open()
  ensure_highlights()
  Snacks.picker.pick("buffers", {
    finder = finder,
    format = format_buffer,
    layout = "telescope",
    actions = {
      toggle_pin = toggle_pin,
      close_unpinned_buffers = close_unpinned_buffers,
    },
    win = {
      input = {
        keys = {
          ["<C-x>"] = { "bufdelete", mode = { "n", "i" }, desc = "close" },
          ["<C-p>"] = { "toggle_pin", mode = { "n", "i" }, desc = "pin" },
          ["<C-d>"] = { "close_unpinned_buffers", mode = { "n", "i" }, desc = "close unpinned" },
        },
      },
      list = {
        border = true,
        footer_keys = { "<C-x>", "<C-d>", "<C-p>" },
        keys = {
          ["<C-x>"] = { "bufdelete", desc = "close" },
          ["<C-p>"] = { "toggle_pin", desc = "pin" },
          ["<C-d>"] = { "close_unpinned_buffers", desc = "close unpinned" },
          ["dd"] = "bufdelete",
          ["P"] = { "toggle_pin", desc = "pin" },
          ["D"] = { "close_unpinned_buffers", desc = "close unpinned" },
        },
      },
    },
  })
end

return M
