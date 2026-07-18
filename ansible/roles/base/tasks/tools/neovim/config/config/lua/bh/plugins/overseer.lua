return {
  "stevearc/overseer.nvim",
  tag = "v2.1.0",
  commit = "95b1099c043e4231a1204abd9a394d379e69f029",
  cmd = {
    "OverseerOpen",
    "OverseerClose",
    "OverseerToggle",
    "OverseerRun",
  },
  keys = {
    {
      "<leader>rr",
      function()
        require("bh.tasks").pick()
      end,
      desc = "[R]un Project Task",
    },
    {
      "<leader>rl",
      function()
        require("bh.overseer-float").toggle()
      end,
      desc = "[R]un Task [L]ist",
    },
    {
      "<leader>rc",
      function()
        require("bh.tasks").run_custom()
      end,
      desc = "[R]un [C]ustom Task",
    },
  },
  opts = {
    task_list = {
      min_height = { 18, 0.35 },
      max_height = { 34, 0.72 },
      min_width = { 110, 0.68 },
      max_width = { 170, 0.90 },
      default_detail = 1,
      keymaps = {},
    },
  },
  config = function(_, opts)
    require("overseer").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "OverseerList",
      callback = function(args)
        vim.wo[0].winbar = " Overseer  [? help] [Enter actions] [p show preview] [q close] "
        vim.wo[0].wrap = false
        vim.wo[0].cursorline = true
        vim.bo[args.buf].buflisted = false
        vim.keymap.set("n", "q", function()
          require("bh.overseer-float").close()
        end, { buffer = args.buf, silent = true, desc = "Close task modal" })
        vim.keymap.set("n", "<Esc>", function()
          require("bh.overseer-float").close()
        end, { buffer = args.buf, silent = true, desc = "Close task modal" })
        vim.keymap.set("n", "p", function()
          require("bh.overseer-float").toggle_preview()
        end, { buffer = args.buf, silent = true, desc = "Toggle preview" })
      end,
    })

    vim.api.nvim_create_autocmd("VimResized", {
      callback = function()
        require("bh.overseer-float").refresh()
      end,
    })
  end,
}
