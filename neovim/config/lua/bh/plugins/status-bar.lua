function filePathComponent()
  local bufferDir = vim.fn.expand("%:p:h")
  local projectDir = require("bh.utils").find_root_dir(bufferDir, { ".git", "package.json" })

  if projectDir ~= nil then
    -- remove one extra level so we don't sub the root dir
    projectDir = vim.fn.fnamemodify(projectDir, ":h")
    bufferDir = string.gsub(bufferDir, projectDir, "")
  end

  return bufferDir
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { "filename" },
        lualine_x = { filePathComponent, "encoding", "filetype", "filesize" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
