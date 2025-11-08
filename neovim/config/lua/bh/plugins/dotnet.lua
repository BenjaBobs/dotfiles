return {
  {
    "seblj/roslyn.nvim",
    ft = "cs",
    opts = {
      -- Configuration for roslyn.nvim
      filewatching = "off", -- Disable filewatching for better performance
      broad_search = false, -- Don't search parent directories (faster startup)
      lock_target = true, -- Lock to first found solution (prevents re-searching)

      config = {
        -- Add any roslyn-specific settings here if needed
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
          },
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles", -- Only analyze open files
            dotnet_compiler_diagnostics_scope = "openFiles", -- Only compiler diagnostics for open files
          },
        },
      },
    },
  },
  {
    "GustavEikaas/easy-dotnet.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    ft = { "cs", "fsproj", "csproj", "sln", "slnx", "props", "targets" },
    opts = {
      -- Configuration for easy-dotnet.nvim
      -- See https://github.com/GustavEikaas/easy-dotnet.nvim for full options
    },
    config = function(_, opts)
      require("easy-dotnet").setup(opts)

      -- Add keymaps under <leader>d for [D]otnet
      vim.keymap.set("n", "<leader>db", function()
        require("easy-dotnet").build()
      end, { desc = "[D]otnet [B]uild" })

      vim.keymap.set("n", "<leader>dr", function()
        require("easy-dotnet").run()
      end, { desc = "[D]otnet [R]un" })

      vim.keymap.set("n", "<leader>dt", function()
        require("easy-dotnet").test()
      end, { desc = "[D]otnet [T]est" })

      vim.keymap.set("n", "<leader>dc", function()
        require("easy-dotnet").clean()
      end, { desc = "[D]otnet [C]lean" })

      vim.keymap.set("n", "<leader>dR", function()
        require("easy-dotnet").restore()
      end, { desc = "[D]otnet [R]estore" })

      vim.keymap.set("n", "<leader>do", function()
        require("easy-dotnet").outdated()
      end, { desc = "[D]otnet [O]utdated packages" })

      vim.keymap.set("n", "<leader>ds", function()
        require("easy-dotnet").secrets()
      end, { desc = "[D]otnet [S]ecrets" })
    end,
  },
}
