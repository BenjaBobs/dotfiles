local M = {}

local excluded_dirs = {
  [".git"] = true,
  [".next"] = true,
  [".turbo"] = true,
  ["bin"] = true,
  ["coverage"] = true,
  ["dist"] = true,
  ["node_modules"] = true,
  ["obj"] = true,
}

local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "file"
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function join(...)
  return normalize(vim.fs.joinpath(...))
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data
end

local function read_json(path)
  local raw = read_file(path)
  if not raw then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    return nil
  end

  return decoded
end

local function walk(dir, on_file)
  for name, kind in vim.fs.dir(dir) do
    local path = join(dir, name)
    if kind == "directory" then
      if not excluded_dirs[name] then
        walk(path, on_file)
      end
    elseif kind == "file" then
      on_file(path, name)
    end
  end
end

local function relative_to(base, path)
  local rel = vim.fs.relpath(base, path)
  return rel or path
end

local function unique_sorted_paths(paths)
  local seen = {}
  local deduped = {}

  for _, path in ipairs(paths) do
    local normalized = normalize(path)
    if not seen[normalized] then
      seen[normalized] = true
      table.insert(deduped, normalized)
    end
  end

  table.sort(deduped)
  return deduped
end

local function detect_project_files(root)
  local package_jsons = {}
  local sln_files = {}
  local csproj_files = {}
  local tsconfig_files = {}

  walk(root, function(path, name)
    if name == "package.json" then
      table.insert(package_jsons, path)
    elseif name:match("%.sln$") then
      table.insert(sln_files, path)
    elseif name:match("%.csproj$") then
      table.insert(csproj_files, path)
    elseif name == "tsconfig.json" then
      table.insert(tsconfig_files, path)
    end
  end)

  return {
    package_jsons = unique_sorted_paths(package_jsons),
    sln_files = unique_sorted_paths(sln_files),
    csproj_files = unique_sorted_paths(csproj_files),
    tsconfig_files = unique_sorted_paths(tsconfig_files),
  }
end

local function has_bun_marker(dir)
  if is_file(join(dir, "bun.lock")) or is_file(join(dir, "bun.lockb")) then
    return true
  end

  local package_json = join(dir, "package.json")
  if not is_file(package_json) then
    return false
  end

  local data = read_json(package_json)
  return data and type(data.packageManager) == "string" and vim.startswith(data.packageManager, "bun@")
end

local function find_bun_root(start_dir, stop_dir)
  local current = normalize(start_dir)
  local stop = normalize(stop_dir)

  while current and vim.startswith(current, stop) do
    if has_bun_marker(current) then
      return current
    end

    if current == stop then
      break
    end

    local parent = vim.fs.dirname(current)
    if not parent or parent == current then
      break
    end
    current = parent
  end

  if has_bun_marker(stop) then
    return stop
  end

  return nil
end

local function format_label(kind, scope, action, cmd, cwd, root)
  local rel_cwd = relative_to(root, cwd)
  if rel_cwd == "." then
    rel_cwd = "."
  end

  return string.format("[%s] %s :: %s :: %s (cwd: %s)", kind, scope, action, cmd, rel_cwd)
end

local function display_command(task)
  local parts = { task.cmd }

  for _, arg in ipairs(task.args or {}) do
    local rel = vim.fs.relpath(task.root, arg)
    table.insert(parts, rel or arg)
  end

  return table.concat(parts, " ")
end

local function add_task(tasks, seen, task)
  local key = table.concat({
    task.kind,
    task.scope,
    task.action,
    task.cwd,
    task.cmd,
    table.concat(task.args or {}, "\x1f"),
  }, "\x1e")

  if seen[key] then
    return
  end
  seen[key] = true

  task.display = format_label(
    task.kind,
    task.scope,
    task.action,
    display_command(task),
    task.cwd,
    task.root
  )

  table.insert(tasks, task)
end

local function package_scope_name(root, package_dir, package_json)
  if type(package_json.name) == "string" and package_json.name ~= "" then
    return package_json.name
  end

  local rel = relative_to(root, package_dir)
  if rel == "." then
    return "."
  end

  return rel
end

local function is_typescript_script(command)
  return type(command) == "string" and command:match("%f[%w]tsc%f[%W]") ~= nil
end

local function add_bun_tasks(root, files, tasks, seen)
  local install_roots = {}

  for _, package_json_path in ipairs(files.package_jsons) do
    local package_dir = vim.fs.dirname(package_json_path)
    local package_json = read_json(package_json_path)
    if not package_json then
      goto continue
    end

    local bun_root = find_bun_root(package_dir, root)
    if not bun_root then
      goto continue
    end

    if not install_roots[bun_root] then
      install_roots[bun_root] = true
      add_task(tasks, seen, {
        root = root,
        kind = "bun",
        scope = relative_to(root, bun_root) == "." and "all" or relative_to(root, bun_root),
        action = "install",
        cwd = bun_root,
        cmd = "bun",
        args = { "install" },
      })
    end

    local scripts = package_json.scripts
    if type(scripts) == "table" then
      local names = vim.tbl_keys(scripts)
      table.sort(names)

      for _, script in ipairs(names) do
        local task = {
          root = root,
          kind = "bun",
          scope = package_scope_name(root, package_dir, package_json),
          action = "run " .. script,
          cwd = package_dir,
          cmd = "bun",
          args = { "run", script },
        }

        task.populate_quickfix = is_typescript_script(scripts[script])
        if task.populate_quickfix then
          task.strategy = { "jobstart", use_terminal = false }
        end

        add_task(tasks, seen, {
          root = task.root,
          kind = task.kind,
          scope = task.scope,
          action = task.action,
          cwd = task.cwd,
          cmd = task.cmd,
          args = task.args,
          populate_quickfix = task.populate_quickfix,
          strategy = task.strategy,
        })
      end
    end

    ::continue::
  end
end

local function is_test_project(csproj_path)
  local contents = read_file(csproj_path)
  if not contents then
    return false
  end

  if contents:match("<IsTestProject>%s*[Tt]rue%s*</IsTestProject>") then
    return true
  end

  return contents:match("PackageReference.-xunit")
    or contents:match("PackageReference.-NUnit")
    or contents:match("PackageReference.-MSTest")
end

local function add_dotnet_tasks(root, files, tasks, seen)
  local has_dotnet = #files.sln_files > 0 or #files.csproj_files > 0
  if not has_dotnet then
    return
  end

  for _, action in ipairs({ "restore", "build", "test" }) do
    add_task(tasks, seen, {
      root = root,
      kind = "dotnet",
      scope = "all",
      action = action,
      cwd = root,
      cmd = "dotnet",
      args = { action },
    })
  end

  for _, sln_path in ipairs(files.sln_files) do
    local rel = relative_to(root, sln_path)
    for _, action in ipairs({ "restore", "build", "test" }) do
      add_task(tasks, seen, {
        root = root,
        kind = "dotnet",
        scope = rel,
        action = action,
        cwd = vim.fs.dirname(sln_path),
        cmd = "dotnet",
        args = { action, sln_path },
      })
    end
  end

  for _, csproj_path in ipairs(files.csproj_files) do
    local rel = relative_to(root, csproj_path)
    for _, action in ipairs({ "restore", "build" }) do
      add_task(tasks, seen, {
        root = root,
        kind = "dotnet",
        scope = rel,
        action = action,
        cwd = vim.fs.dirname(csproj_path),
        cmd = "dotnet",
        args = { action, csproj_path },
      })
    end

    if is_test_project(csproj_path) then
      add_task(tasks, seen, {
        root = root,
        kind = "dotnet",
        scope = rel,
        action = "test",
        cwd = vim.fs.dirname(csproj_path),
        cmd = "dotnet",
        args = { "test", csproj_path },
      })
    end
  end
end

local function typescript_scope_name(root, tsconfig_path)
  local dir = vim.fs.dirname(tsconfig_path)
  local rel = relative_to(root, dir)
  if rel == "." then
    return "all"
  end

  return rel
end

local function typescript_command(root, cwd)
  local bun_root = find_bun_root(cwd, root)
  if bun_root then
    return "bunx", { "tsc" }
  end

  return "tsc", {}
end

local function add_typescript_tasks(root, files, tasks, seen)
  for _, tsconfig_path in ipairs(files.tsconfig_files) do
    local cwd = vim.fs.dirname(tsconfig_path)
    local cmd, base_args = typescript_command(root, cwd)
    local args = vim.list_extend(vim.deepcopy(base_args), {
      "--pretty",
      "false",
      "--noEmit",
      "-p",
      tsconfig_path,
    })

    add_task(tasks, seen, {
      root = root,
      kind = "tsc",
      scope = typescript_scope_name(root, tsconfig_path),
      action = "check",
      cwd = cwd,
      cmd = cmd,
      args = args,
      populate_quickfix = true,
      strategy = { "jobstart", use_terminal = false },
    })
  end
end

local function populate_quickfix_from_lines(task, lines)
  if vim.tbl_isempty(lines) then
    if task.exit_code and task.exit_code ~= 0 then
      vim.notify("Task failed, but no output lines were collected", vim.log.levels.WARN)
    end
    return
  end

  lines = vim.tbl_map(function(line)
    line = line:gsub("\27%[[0-9;?]*[%a]", "")
    line = line:gsub("\r", "")
    return line
  end, lines)

  local items = {}
  local current = nil

  local function push_current()
    if not current then
      return
    end

    table.insert(items, current)
    current = nil
  end

  for _, line in ipairs(lines) do
    local filename, lnum, col, severity, code, message =
      line:match("^(.+)%((%d+),(%d+)%)%: (%a+) TS(%d+)%: (.+)$")

    if not filename then
      filename, lnum, col, severity, code, message =
        line:match("^(.+):(%d+):(%d+) %- (%a+) TS(%d+)%: (.+)$")
    end

    if filename and (severity == "error" or severity == "warning") then
      push_current()
      local resolved = filename
      if not resolved:match("^/") then
        resolved = join(task.cwd or vim.fn.getcwd(), resolved)
      end

      current = {
        filename = normalize(resolved),
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = message,
        type = severity == "warning" and "W" or "E",
        nr = tonumber(code),
        valid = 1,
      }
    elseif current
      and line:match("^%s%s+")
      and not line:match("^%s*~+")
      and not line:match("^%s*%d+")
      and not line:match("^Found %d+ errors?%.?$")
      and not line:match("^error: script ")
    then
      current.text = current.text .. "\n" .. vim.trim(line)
    end
  end

  push_current()

  vim.fn.setqflist({}, "r", {
    title = task.name,
    items = items,
  })

  if not vim.tbl_isempty(items) then
    vim.cmd.copen()
  elseif task.exit_code and task.exit_code ~= 0 then
    local preview = vim.list_slice(lines, 1, math.min(#lines, 12))
    vim.notify("Task failed, but no quickfix items were parsed", vim.log.levels.WARN)
    vim.notify(table.concat(preview, "\n"), vim.log.levels.INFO, { title = "TS task raw output" })
  end
end

function M.collect(root)
  root = normalize(root or vim.fn.getcwd())

  if not is_dir(root) then
    return {}
  end

  local files = detect_project_files(root)
  local tasks = {}
  local seen = {}

  add_bun_tasks(root, files, tasks, seen)
  add_typescript_tasks(root, files, tasks, seen)
  add_dotnet_tasks(root, files, tasks, seen)

  table.sort(tasks, function(a, b)
    return a.display < b.display
  end)

  return tasks
end

function M.run(task)
  local overseer = require("overseer")
  local command = table.concat(vim.list_extend({ task.cmd }, vim.deepcopy(task.args or {})), " ")

  local overseer_task = overseer.new_task({
    name = task.display,
    cwd = task.cwd,
    cmd = task.cmd,
    args = task.args,
    env = task.env,
    strategy = task.strategy,
    metadata = {
      source = "bh.tasks",
      kind = task.kind,
      scope = task.scope,
      action = task.action,
      command = command,
    },
  })

  if task.populate_quickfix then
    local output_lines = {}

    overseer_task:subscribe("on_output_lines", function(_, lines)
      vim.list_extend(output_lines, lines)
    end)

    overseer_task:subscribe("on_complete", function()
      vim.schedule(function()
        local current = vim.fn.getcwd()
        local ok, err = pcall(populate_quickfix_from_lines, overseer_task, output_lines)
        vim.fn.chdir(current)
        if not ok then
          vim.notify("Failed to populate quickfix: " .. err, vim.log.levels.ERROR)
        end
      end)
    end)
  end

  overseer_task:start()
  vim.notify("Started task: " .. command, vim.log.levels.INFO)
end

function M.run_custom()
  vim.ui.input({ prompt = "Task command: ", completion = "shellcmdline" }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    local command = vim.trim(input)
    local overseer = require("overseer")
    local task = overseer.new_task({
      name = "[custom] " .. command,
      cmd = command,
      cwd = vim.fn.getcwd(),
      metadata = {
        source = "bh.tasks",
        kind = "custom",
        command = command,
      },
    })

    task:start()
    vim.notify("Started task: " .. command, vim.log.levels.INFO)
  end)
end

function M.pick()
  local tasks = M.collect()
  if vim.tbl_isempty(tasks) then
    vim.notify("No project tasks found in current working directory", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, task in ipairs(tasks) do
    table.insert(items, {
      text = task.display,
      task = task,
    })
  end

  Snacks.picker.pick(nil, {
    title = "Project Tasks",
    items = items,
    format = "text",
    layout = "select",
    confirm = function(picker, item)
      picker:close()
      if item and item.task then
        M.run(item.task)
      end
    end,
  })
end

return M
