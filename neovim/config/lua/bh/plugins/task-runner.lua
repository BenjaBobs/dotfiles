return {
  "stevearc/overseer.nvim",
  config = function()
    local overseer = require("overseer")
    overseer.setup({
      templates = { "builtin" },
    })

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    vim.keymap.set("n", "<leader>ft", function()
      local availableTasks = {}

      -- Load package-json tasks from your custom module.
      local pkgTasks = require("bh.plugins.tasks.package-json").find_tasks()
      for _, task in ipairs(pkgTasks) do
        table.insert(availableTasks, task)
      end

      -- Append Overseer tasks already registered.
      for _, t in ipairs(overseer.list_tasks()) do
        table.insert(availableTasks, t)
      end

      pickers
        .new({}, {
          prompt_title = "Project Tasks",
          finder = finders.new_table({
            results = availableTasks,
            entry_maker = function(entry)
              -- Create a display string: if there's a description, show it.
              local name = entry.name or "[Unnamed Task]"
              local description = entry.description or ""
              return {
                value = entry,
                display = description ~= "" and (name .. " - " .. description) or name,
                ordinal = name,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
              local selection = action_state.get_selected_entry().value
              actions.close(prompt_bufnr)
              if selection.cmd then
                -- Package-json task: create and start a new Overseer task.
                print("Running package-json task: " .. selection.name)
                local Task = require("overseer.task")
                Task:new({
                  cmd = vim.split(selection.cmd, "%s+"),
                  cwd = vim.fn.getcwd(),
                }):start()
              else
                -- Overseer task object: assume it has a start() method.
                print("Running Overseer task: " .. (selection.name or "Unnamed Task"))
                if selection.start then
                  selection:start()
                else
                  vim.notify("Selected task cannot be started", vim.log.levels.ERROR)
                end
              end
            end)
            return true
          end,
        })
        :find()
    end, { desc = "Run Project Task" })
  end,
}
