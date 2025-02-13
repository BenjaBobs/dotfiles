return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup({
      defaults = {
        path_display = { "shorten" },
      },
    })

    local builtin = require("telescope.builtin")

    vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "[F]iles" })
    vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "[G]rep" })
    vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[H]elp" })
    vim.keymap.set("n", "<leader>fn", function()
      builtin.find_files({ cwd = vim.fn.stdpath("config") })
    end, { desc = "[N]eovim config files" })
    vim.keymap.set("n", "<leader>fb", builtin.current_buffer_fuzzy_find, { desc = "Current [b]uffer" })
  end,
}
