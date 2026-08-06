return {
  "shellRaining/hlchunk.nvim",
  tag = "v1.3.0",
  commit = "d5e45809ed93991ade8e10e4f706cd7699b17430",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local opts = {
      chunk = {
        enable = true,
        delay = 50,
        duration = 50,
        chars = {
          horizontal_line = "─",
          vertical_line = "│",
          left_top = "╭",
          left_bottom = "╰",
          right_arrow = "─",
        },
      },
      indent = {
        enable = true,
      },
      line_num = {
        enable = true,
      },
    }

    require("hlchunk").setup(opts)

    -- hlchunk draws its guides as `virt_text_pos = "overlay"` extmarks, so a guide
    -- placed at a column that holds real text hides that character on screen (the
    -- buffer itself is untouched, which is why yanking still gives the full line).
    -- It only re-renders on TextChanged/BufWinEnter/WinScrolled, and a reload
    -- triggered by an external write fires none of those -- it fires BufReadPost and
    -- FileChangedShellPost. The per-line indent cache and extmark-id cache therefore
    -- survive the reload and describe the *old* contents, leaving guides sitting on
    -- top of the new text. Those caches are module-locals, so the only way to drop
    -- them is to reload the modules; ~5ms, and only on an external change.
    vim.api.nvim_create_autocmd({ "FileChangedShellPost", "BufReadPost" }, {
      group = vim.api.nvim_create_augroup("bh_hlchunk_reload", { clear = true }),
      callback = function(event)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(event.buf) then
            return
          end
          for _, cmd in ipairs({ "DisableHLIndent", "DisableHLChunk", "DisableHLLineNum" }) do
            pcall(vim.cmd, cmd)
          end
          for name in pairs(package.loaded) do
            if name == "hlchunk" or name:match("^hlchunk%.") then
              package.loaded[name] = nil
            end
          end
          require("hlchunk").setup(opts)
          vim.api.nvim_exec_autocmds("TextChanged", { buffer = event.buf, modeline = false })
        end)
      end,
    })
  end,
}
