function filePathComponent()
  return require("bh.lib.utils").find_root_relative_buffer_dir()

  -- local bufferDir = vim.fn.expand("%:p:h")
  -- local projectDir = require("bh.lib.utils").find_root_dir(bufferDir, { ".git", "package.json" })
  --
  -- if projectDir ~= nil then
  --   -- remove one extra level so we don't sub the root dir
  --   projectDir = vim.fn.fnamemodify(projectDir, ":h")
  --   bufferDir = string.gsub(bufferDir, projectDir, "")
  -- end
  --
  -- return bufferDir
end

return {
  "nvim-lualine/lualine.nvim",
  -- No current semver release tag; compatibility tags point at old Neovim support branches.
  commit = "221ce6b2d999187044529f49da6554a92f740a96",
  config = function()
    require("lualine").setup({
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { filePathComponent },
        lualine_x = {
          -- Sits before the file info so a running test is the first thing on
          -- that side of the bar. Inert until a test is actually run.
          {
            function()
              return require("bh.features.test-status").lualine()
            end,
            color = function()
              return require("bh.features.test-status").lualine_color()
            end,
          },
          "filename",
          "encoding",
          "filetype",
          "filesize",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
