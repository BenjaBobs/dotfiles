return {
  "nvim-neotest/neotest",
  commit = "4e2cd42c4252ee9d2435571d9adcdbc1d47931fe",
  dependencies = {
    {
      "nvim-neotest/nvim-nio",
      commit = "edcc181a875301dd21840189aa2f2f9ad69fc172",
    },
    {
      "nvim-lua/plenary.nvim",
      commit = "74b06c6c75e4eeb3108ec01852001636d85a932b",
    },
    {
      "Issafalcon/neotest-dotnet",
      commit = "e27c67a856ce67cc968b773d01a35ec07459bb8b",
    },
    {
      "marilari88/neotest-vitest",
      commit = "c3c69715da4b158069fd4262083e7219a5c14cfb",
    },
    {
      "thejchap/neotest-zig",
      commit = "5fca16d93170a8d1a2949abf9b351f48389501be",
    },
  },
  keys = {
    {
      "<leader>tt",
      function()
        require("neotest").run.run()
      end,
      desc = "[T]est Nearest",
    },
    {
      "<leader>tf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "Test [F]ile",
    },
    {
      "<leader>ta",
      function()
        require("neotest").run.run(vim.uv.cwd())
      end,
      desc = "Test [A]ll",
    },
    {
      "<leader>tl",
      function()
        require("neotest").run.run_last()
      end,
      desc = "Test [L]ast",
    },
    {
      "<leader>tw",
      function()
        require("neotest").watch.toggle(vim.fn.expand("%"))
      end,
      desc = "Test [W]atch File",
    },
    {
      "<leader>tx",
      function()
        require("neotest").run.stop()
      end,
      desc = "[X] Test Stop",
    },
    {
      "<leader>ts",
      function()
        require("neotest").summary.toggle()
      end,
      desc = "Test [S]ummary",
    },
    {
      "<leader>to",
      function()
        require("neotest").output.open({ enter = true })
      end,
      desc = "Test [O]utput",
    },
    {
      "<leader>tp",
      function()
        require("neotest").output_panel.toggle()
      end,
      desc = "Test Output [P]anel",
    },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-dotnet")({}),
        require("neotest-vitest")({
          filter_dir = function(name)
            return name ~= "node_modules"
              and name ~= ".git"
              and name ~= ".next"
              and name ~= ".turbo"
              and name ~= "coverage"
              and name ~= "dist"
          end,
        }),
        require("neotest-zig")({}),
      },
      output = {
        open_on_run = "short",
      },
      quickfix = {
        open = false,
      },
    })
  end,
}
