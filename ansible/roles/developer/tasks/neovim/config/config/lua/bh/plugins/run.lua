return {
  {
    "numToStr/FTerm.nvim",
    config = function()
      local fterm = require("FTerm")
      local Terminal = require("FTerm.terminal")
      local uname = vim.loop.os_uname().sysname
      local cwd = vim.fn.getcwd()
      local shell

      if uname == "Windows_NT" then
        -- Adjust this depending on your preferred shell
        shell = { "powershell.exe", "-NoLogo", "-NoExit", "-Command", "cd '" .. cwd .. "'" }
        -- shell = { "cmd.exe", "/K", "cd /d " .. cwd }
        -- shell = { "wsl.exe" } -- WSL automatically starts in cwd
      else
        -- Assuming bash or compatible shell
        shell = {
          os.getenv("SHELL") or "/bin/bash",
          "-c",
          "cd " .. cwd .. " && exec " .. (os.getenv("SHELL") or "/bin/bash"),
        }
      end

      fterm.setup({
        cmd = shell,
      })

      vim.keymap.set("n", "<leader>rt", fterm.toggle, { desc = "[R]un [T]erminal" })
      vim.keymap.set("n", "<leader>rg", function()
        fterm.scratch({
          cmd = "gitui",
        })
      end, { desc = "[R]un [G]itui" })

      vim.keymap.set("n", "<leader>rn", function()
        Snacks.picker.commands()
      end, { desc = "[R]un [N]eovim Command" })
    end,
  },
}
