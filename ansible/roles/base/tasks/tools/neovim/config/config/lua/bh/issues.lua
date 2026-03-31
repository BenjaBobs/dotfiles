local M = {}

function M.workspace_diagnostics_to_quickfix()
  local diagnostics = vim.diagnostic.get(nil)

  if vim.tbl_isempty(diagnostics) then
    vim.notify("No diagnostics", vim.log.levels.INFO)
    return
  end

  vim.diagnostic.setqflist({
    title = "Workspace Diagnostics",
    open = false,
  })
  vim.cmd.copen()
end

function M.open_quickfix()
  local quickfix = vim.fn.getqflist({ size = 0, title = 0 })

  if quickfix.size == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.INFO)
    return
  end

  vim.cmd.copen()
end

function M.quickfix_next()
  local quickfix = vim.fn.getqflist({ size = 0 })

  if quickfix.size == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.INFO)
    return
  end

  vim.cmd.cnext()
end

function M.quickfix_prev()
  local quickfix = vim.fn.getqflist({ size = 0 })

  if quickfix.size == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.INFO)
    return
  end

  vim.cmd.cprev()
end

function M.diagnostic_next()
  vim.diagnostic.jump({ count = 1, float = true })
end

function M.diagnostic_prev()
  vim.diagnostic.jump({ count = -1, float = true })
end

return M
