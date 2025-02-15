local export = {}

function export.find_root_dir(start_path, markers)
  if vim.uv.fs_stat(start_path) == nil then
    return nil
  end

  local upperMostDir = nil
  local currentDir = start_path

  while currentDir and currentDir ~= "" do
    for _, marker in ipairs(markers) do
      local marker_path = currentDir .. "/" .. marker
      if vim.uv.fs_stat(marker_path) ~= nil then
        upperMostDir = currentDir -- update candidate if marker is found
        break
      end
    end

    -- Move one directory up.
    local parent = vim.fn.fnamemodify(currentDir, ":h")
    if parent == currentDir then
      break -- reached the filesystem root
    end
    currentDir = parent
  end

  return upperMostDir
end

return export
