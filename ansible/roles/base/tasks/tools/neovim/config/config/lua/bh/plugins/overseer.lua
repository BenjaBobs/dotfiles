return {
  "stevearc/overseer.nvim",
  cmd = {
    "OverseerOpen",
    "OverseerClose",
    "OverseerToggle",
    "OverseerRun",
  },
  keys = {
    {
      "<leader>tr",
      function()
        require("bh.tasks").pick()
      end,
      desc = "[T]ask [R]un",
    },
    {
      "<leader>tl",
      function()
        require("bh.overseer-float").toggle()
      end,
      desc = "[T]ask [L]ist",
    },
    {
      "<leader>tc",
      function()
        require("bh.tasks").run_custom()
      end,
      desc = "[T]ask Run [C]ustom",
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
