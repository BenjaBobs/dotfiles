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
      -- Only listed keys are overridden; every other overseer default survives.
      keymaps = {
        ["<CR>"] = {
          "keymap.open",
          opts = { dir = "float" },
          desc = "Open task output in a float",
        },
        ["a"] = "keymap.run_action",
      },
    },
    actions = {
      -- Overseer's built-in open actions assume the task list is a docked side
      -- panel, so they leave our float covering the output window. Route the
      -- float variant through bh.overseer-float, which closes the list first
      -- and binds q on the output buffer.
      ["open float"] = {
        desc = "open terminal in a floating window",
        condition = function(task)
          return task:get_bufnr() ~= nil
        end,
        run = function(task)
          require("bh.overseer-float").open_output(task)
        end,
      },
    },
  },
  config = function(_, opts)
    require("overseer").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "OverseerList",
      callback = function(args)
        vim.wo[0].winbar = " Overseer  [? help] [Enter output] [a actions] [p show preview] [q close] "
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
