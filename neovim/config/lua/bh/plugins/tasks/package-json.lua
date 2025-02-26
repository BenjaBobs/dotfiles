return {
  find_tasks = function()
    -- Find the project root. (Assumes you have a utility function for this.)
    local utils = require("bh.utils")
    local project_dir = utils.find_root_dir(vim.fn.expand("%:p:h"), { "package.json" })

    if not project_dir then
      -- No tasks here
      return {}
    end

    -- Read and decode package.json.
    local pkg_path = project_dir .. "/package.json"
    local pkg_lines = vim.fn.readfile(pkg_path)
    if not pkg_lines or vim.tbl_isempty(pkg_lines) then
      return {}
    end

    local pkg_json = vim.fn.json_decode(table.concat(pkg_lines, "\n"))
    if not pkg_json then
      -- No tasks in package.json
      return {}
    end

    -- Prepare a list of script entries.
    local results = {
      { name = "Project: yarn install", description = "", cmd = "yarn install" },
    }

    for script, cmd in pairs(pkg_json.scripts or {}) do
      table.insert(results, { name = "Project: yarn run " .. script, description = cmd, cmd = "yarn run " .. cmd })
    end

    return results
  end,
}
