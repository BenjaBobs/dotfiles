local TaskView = require("overseer.task_view")

local M = {}

local preview = nil

local function list_bufnr()
  local sidebar = require("overseer.task_list.sidebar").get_or_create()
  local bufnr = sidebar.bufnr
  vim.bo[bufnr].filetype = "OverseerList"
  vim.bo[bufnr].buflisted = false
  return bufnr
end

local function list_window()
  local bufnr = list_bufnr()
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
end

local function editor_box()
  local columns = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local width = math.max(80, math.floor(columns * 0.9))
  local height = math.max(18, math.floor(lines * 0.9))

  return {
    row = math.floor((lines - height) / 2),
    col = math.floor((columns - width) / 2),
    width = width,
    height = height,
  }
end

local function list_config(with_preview)
  local box = editor_box()
  local width = box.width

  if with_preview then
    width = math.floor(box.width * 0.42)
  end

  return {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width,
    height = box.height,
    row = box.row,
    col = box.col,
    title = " Overseer ",
    title_pos = "center",
  }
end

local function preview_config()
  local box = editor_box()
  local list_width = math.floor(box.width * 0.42)
  local preview_width = box.width - list_width - 1

  return {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = preview_width,
    height = box.height,
    row = box.row,
    col = box.col + list_width + 1,
    title = " Task Output ",
    title_pos = "center",
  }
end

local function configure_list_window(winid, with_preview)
  local preview_hint = with_preview and "hide preview" or "show preview"
  vim.wo[winid].winbar =
    string.format(" Overseer  [? help] [Enter actions] [p %s] [q close] ", preview_hint)
  vim.wo[winid].wrap = false
  vim.wo[winid].cursorline = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
end

local function close_preview()
  if preview and not preview:is_win_closed() then
    preview:dispose()
  end
  preview = nil
end

function M.open()
  local winid = list_window()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
    return winid
  end

  local bufnr = list_bufnr()
  winid = vim.api.nvim_open_win(bufnr, true, list_config(false))
  configure_list_window(winid, false)
  return winid
end

function M.toggle_preview()
  local winid = M.open()
  if preview and not preview:is_win_closed() then
    close_preview()
    vim.api.nvim_win_set_config(winid, list_config(false))
    configure_list_window(winid, false)
    return
  end

  vim.api.nvim_win_set_config(winid, list_config(true))
  configure_list_window(winid, true)

  local preview_win = vim.api.nvim_open_win(0, false, preview_config())
  preview = TaskView.new(preview_win, {
    close_on_list_close = false,
    select = function(_, tasks, task_under_cursor)
      return task_under_cursor or tasks[1]
    end,
  })
end

function M.refresh()
  local winid = list_window()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_config(winid, list_config(preview and not preview:is_win_closed()))
    configure_list_window(winid, preview and not preview:is_win_closed())
  end

  if preview and not preview:is_win_closed() then
    vim.api.nvim_win_set_config(preview.winid, preview_config())
  end
end

function M.close()
  close_preview()

  local winid = list_window()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, false)
  end
end

function M.toggle()
  local winid = list_window()
  if winid and vim.api.nvim_win_is_valid(winid) then
    M.close()
  else
    M.open()
  end
end

return M
