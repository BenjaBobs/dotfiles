-- Every keymap here goes through bh.features.test-status rather than calling
-- neotest directly. neotest's run() returns immediately and does the real work
-- in a coroutine, so without a wrapper there is nothing between the keypress
-- and, a minute later, a result. See that module for the whole story.
local function test_status()
  return require("bh.features.test-status")
end

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
      -- Successor to Issafalcon/neotest-dotnet, which is unmaintained and broken
      -- on Neovim 0.12 (it uses the iter_matches capture shape removed in 0.12).
      -- Discovers tests through VSTest/Microsoft.Testing.Platform instead of
      -- treesitter, so it handles every framework, TUnit included.
      "nsidorenco/neotest-vstest",
      commit = "8588c3c988c7ed49879dddf937b42681cfa7ce30",
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
        test_status().run_nearest()
      end,
      desc = "[T]est Nearest",
    },
    {
      "<leader>tf",
      function()
        test_status().run_file()
      end,
      desc = "Test [F]ile",
    },
    {
      "<leader>ta",
      function()
        test_status().run_all()
      end,
      desc = "Test [A]ll",
    },
    {
      "<leader>tl",
      function()
        test_status().run_last()
      end,
      desc = "Test [L]ast",
    },
    {
      "<leader>tw",
      function()
        test_status().watch_file()
      end,
      desc = "Test [W]atch File",
    },
    {
      "<leader>tx",
      function()
        test_status().stop()
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
    {
      -- The "why is nothing happening" key: adapters, what was discovered where,
      -- what is running right now, and the last thing neotest tried to say.
      "<leader>ti",
      function()
        test_status().report()
      end,
      desc = "Test [I]nfo / status",
    },
    {
      "<leader>tg",
      function()
        test_status().open_log()
      end,
      desc = "Test Lo[g]",
    },
  },
  config = function()
    local status = require("bh.features.test-status")

    require("neotest").setup({
      -- INFO rather than WARN: the log is the only record of why a discovery
      -- came back empty, and <leader>tg exists to read it.
      log_level = vim.log.levels.INFO,
      adapters = vim.tbl_map(status.instrument, {
        -- Configured through vim.g.neotest_vstest, not call arguments.
        require("neotest-vstest"),
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
      }),
      consumers = status.consumers(),
      output = {
        open_on_run = "short",
      },
      quickfix = {
        open = false,
      },
      status = {
        -- Signs share the gutter with git and diagnostics, so the test state
        -- can be the thing that loses. Virtual text puts the spinner on the
        -- line you just ran, which is where you are already looking.
        virtual_text = true,
        signs = true,
      },
    })

    status.setup()
  end,
}
