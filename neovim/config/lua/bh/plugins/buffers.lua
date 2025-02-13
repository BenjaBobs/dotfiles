return {
  "axkirillov/hbac.nvim",
  config = function()
    local actions = require("hbac.telescope.actions")

    require("hbac").setup({
      autoclose = true, -- set autoclose to false if you want to close manually
      threshold = 10, -- hbac will start closing unedited buffers once that number is reached
      close_command = function(bufnr)
        vim.api.nvim_buf_delete(bufnr, {})
      end,
      close_buffers_with_windows = false, -- hbac will close buffers with associated windows if this option is `true`
      telescope = {
        -- See #telescope-configuration below
        use_default_mappings = false,
        mappings = {
          i = {
            ["<C-p>"] = actions.toggle_pin,
            ["<C-d>"] = actions.delete_buffer,
            ["<C-q>"] = actions.close_unpinned,
          },
        },
      },
    })

    require("telescope").load_extension("hbac")

    vim.keymap.set("n", "<leader>fo", function()
      require("telescope").extensions.hbac.buffers()
    end, { desc = "[O]pen buffers" })
  end,
}
