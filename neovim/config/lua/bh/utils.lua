local export = {}

local defaultMarkers = { ".git", "package.json" }

function export.find_root_dir(start_path, markers)
  if vim.uv.fs_stat(start_path) == nil then
    return nil
  end

  local upperMostDir = nil
  local currentDir = start_path

  while currentDir and currentDir ~= "" do
    for _, marker in ipairs(markers or defaultMarkers) do
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

function export.find_root_relative_file_path(start_path, markers)
  local path = start_path
  local projectDir = export.find_root_dir(path, markers)

  if projectDir ~= nil then
    -- remove one extra level so we don't sub the root dir
    projectDir = vim.fn.fnamemodify(projectDir, ":h")
    path = string.gsub(path, projectDir, "")
  end

  return path
end

function export.find_root_relative_buffer_path(markers)
  return export.find_root_relative_file_path(vim.fn.expand("%:p"), markers)
end

function export.find_root_relative_buffer_dir(markers)
  local filePath = export.find_root_relative_buffer_path(markers)
  return vim.fn.fnamemodify(filePath, ":h")
end

return export
