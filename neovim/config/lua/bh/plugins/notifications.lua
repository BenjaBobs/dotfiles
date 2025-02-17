return {
  "rcarriga/nvim-notify",
  config = function()
    local notify = require("notify")
    notify.setup()

    -- Replace vim's default notification system with nvim-notify
    vim.notify = notify

    vim.keymap.set("n", "<leader>fn", function()
      require("telescope").extensions.notify.notify()
    end, { desc = "[N]otifications" })

    -- Create an autocommand for before saving the buffer.
    vim.api.nvim_create_autocmd("BufWritePre", {
      callback = function()
        -- Record the start time (in nanoseconds).
        vim.b.save_start_time = vim.loop.hrtime()

        local file_path = vim.fn.expand("%:p")
        local msg = string.format("Saving '%s'...", file_path)
        -- Show a notification that the buffer is saving.
        -- The returned notify ID is stored in a buffer variable so we can replace it later.
        vim.b.save_notify_id = vim.notify(msg, vim.log.levels.INFO, {
          title = "Buffer Save",
          timeout = 1000, -- Optional: auto-dismiss after a short time.
        })
      end,
    })

    -- Create an autocommand for after saving the buffer.
    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = function()
        -- Get the end time and compute the elapsed time in milliseconds.
        local end_time = vim.loop.hrtime()
        local elapsed_ms = (end_time - (vim.b.save_start_time or end_time)) / 1e6

        -- Get the file path of the current buffer and its size in bytes.
        local file_path = vim.fn.expand("%:p")
        local bytes_written = vim.fn.getfsize(file_path)

        -- Build the message.
        local msg = string.format("Saved '%s': %d bytes in %.2f ms", file_path, bytes_written, elapsed_ms)

        -- Update the previous notification by replacing it (if available).
        vim.notify(msg, vim.log.levels.INFO, {
          title = "Buffer Save",
          icon = "✓",
          replace = vim.b.save_notify_id,
          timeout = 3000, -- Keep it visible a bit longer.
        })
      end,
    })
  end,
}
