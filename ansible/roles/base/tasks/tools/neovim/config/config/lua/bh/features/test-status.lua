------------------
-- Feedback for the test runner.
--
-- neotest does all of its work in coroutines and says almost nothing while it
-- is busy. The first <leader>tt in a C# solution can spend a minute inside
-- `dotnet build` and a pile of `dotnet msbuild -getProperty:...` calls before a
-- single test is even discovered, and the only outward sign is that the editor
-- feels dead. When discovery then quietly comes back empty -- an MTP/TUnit
-- project whose discovery request hit its 30s timeout, a project that is not
-- listed in the .sln -- the whole thing ends in one easily-missed
-- "No tests found".
--
-- So this module makes the invisible parts visible:
--
--   * a sticky notification naming the current phase and how long it has been
--     running, replaced in place rather than stacked
--   * a lualine component, so there is always somewhere to look
--   * a pass/fail summary with a duration when a run finishes
--   * :TestStatus -- everything the runner currently believes, for the times
--     when the answer really is "nothing is happening"
--
-- None of it is language-specific. Everything below works through interfaces
-- every neotest adapter implements, in three layers:
--
--   1. Our keymap wrappers, which fire *before* neotest has had a chance to do
--      anything -- the bit that answers "did my keypress register?".
--   2. neotest's consumer events (starting/started, run, results), registered
--      as a named consumer so we get our own listener slots and do not clobber
--      the built-in ones.
--   3. Wrappers around the neotest.Adapter functions themselves -- root,
--      is_test_file, discover_positions, build_spec, results -- applied
--      uniformly to every adapter in the setup call. This is where the phase
--      names and the command being run come from, for dotnet and vitest and
--      zig alike.
--
-- One optional fourth layer sits on top for neotest-vstest specifically, and
-- only because dotnet hides work the adapter interface cannot expose: a
-- `dotnet build` of the whole solution before every run, and a test host
-- launched over a socket to discover tests. Those are extra detail on a
-- picture that is already complete without them -- an adapter with no such
-- wrapper loses nothing but the words "Building MyApp.sln". Adding the same
-- for another language means one more function down there, nothing else.
--
-- Every wrapper only observes: it calls through and returns the original value.
------------------

local M = {}

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local NOTIFY_ID = "bh_test_status"
local TITLE = "Test"
local TICK_MS = 120
-- How long a request may sit with nothing else to show for it before we admit
-- we have lost track of it and point at :TestStatus.
local STALLED_AFTER = 20
-- Work nobody asked for -- a re-scan after a save, say -- stays out of the
-- notification until it has run this long. Past that it is no longer
-- background noise, it is the reason the editor feels stuck.
local PROMOTE_AFTER = 5
local EVENT_LOG_MAX = 40

local state = {
  -- id -> { label, started, seq, foreground }. An "activity" is one thing
  -- taking time. Foreground means "started because the user asked for a run",
  -- and only foreground work may take over the notification -- otherwise a
  -- background re-scan would wipe the result summary a second after it lands.
  activities = {},
  seq = 0,
  -- True between a run request and its result: everything started in that
  -- window is the user's own doing.
  requesting = false,
  timer = nil,
  rendered = nil,
  -- Whether the notification is currently showing progress (as opposed to a
  -- finished summary that must not be hidden out from under the reader).
  showing_progress = false,
  -- In-flight run: { started, count, done, test_ids, adapter }
  run = nil,
  -- Last finished run: { passed, failed, skipped, total, duration, at }
  summary = nil,
  -- Last thing neotest itself tried to tell the user.
  last_message = nil,
  -- Aggregated file discovery, so a 400-file scan is one line and not 400.
  discovery = { in_flight = 0, files = 0, tests = 0, stop_timer = nil },
  -- Per test binary: how many tests came back, and how long it took.
  discovered = {},
  -- Rolling log of what happened, for :TestStatus.
  events = {},
}

------------------
-- Small helpers
------------------

local function now()
  return vim.uv.hrtime() / 1e9
end

--- For durations that are over: precise, because "did the build take 0.3s or
--- 40s" is the whole question.
local function fmt_duration(seconds)
  if seconds < 1 then
    return string.format("%.0fms", seconds * 1000)
  end
  if seconds < 60 then
    return string.format("%.1fs", seconds)
  end
  return string.format("%dm%02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

--- For counters that are still running: whole seconds only, so the rendered
--- line changes once a second rather than on every 120ms tick.
local function fmt_elapsed(seconds)
  if seconds < 60 then
    return string.format("%ds", math.floor(seconds))
  end
  return string.format("%dm%02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function spinner_frame()
  return SPINNER[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #SPINNER + 1]
end

local function plural(n, word)
  return string.format("%d %s%s", n, word, n == 1 and "" or "s")
end

--- Append to the rolling event log shown by :TestStatus.
local function log(fmt, ...)
  local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  table.insert(state.events, { at = os.date("%H:%M:%S"), text = text })
  if #state.events > EVENT_LOG_MAX then
    table.remove(state.events, 1)
  end
end

---@param only_notifiable boolean|nil drop background work that is still young
local function active_sorted(only_notifiable)
  local list = {}
  for id, activity in pairs(state.activities) do
    local since = now() - (activity.promote_from or activity.started)
    if not only_notifiable or activity.foreground or since > PROMOTE_AFTER then
      list[#list + 1] = {
        id = id,
        label = activity.label,
        started = activity.started,
        seq = activity.seq,
      }
    end
  end
  table.sort(list, function(a, b)
    return a.seq < b.seq
  end)
  return list
end

function M.is_busy()
  return next(state.activities) ~= nil
end

------------------
-- The notification
------------------

local function progress_message()
  local lines = {}
  local list = active_sorted(true)
  for _, activity in ipairs(list) do
    local age = now() - activity.started
    local line = string.format("%s (%s)", activity.label, fmt_elapsed(age))
    -- A lone request that has gone quiet is the failure mode this module
    -- exists for, so say so instead of spinning forever without comment.
    if #list == 1 and activity.id == "request" and age > STALLED_AFTER then
      line = line .. "  (no response yet — :TestStatus)"
    end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end

local function notify_progress()
  local message = progress_message()
  if message == "" then
    return
  end
  state.showing_progress = true
  vim.notify(message, vim.log.levels.INFO, {
    id = NOTIFY_ID,
    title = TITLE,
    timeout = false,
    opts = function(notif)
      notif.icon = spinner_frame()
    end,
  })
end

--- Only ever takes down our own spinner: a finished summary occupies the same
--- slot and has to stay long enough to be read.
local function hide_progress()
  if not state.showing_progress then
    return
  end
  state.showing_progress = false
  if _G.Snacks and _G.Snacks.notifier then
    pcall(_G.Snacks.notifier.hide, NOTIFY_ID)
  end
end

local function stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function tick()
  if not M.is_busy() then
    hide_progress()
    stop_timer()
    return
  end
  -- Re-notify only when the rendered text actually changes (once a second, as
  -- the elapsed counter ticks over); the spinner animates itself through the
  -- dynamic `opts` callback above.
  local message = progress_message()
  if message ~= state.rendered then
    state.rendered = message
    if message == "" then
      -- Only background work left: keep it in the statusline, take the
      -- notification down.
      hide_progress()
    else
      notify_progress()
    end
  end
  pcall(vim.cmd.redrawstatus)
end

local function ensure_timer()
  if state.timer then
    return
  end
  state.timer = vim.uv.new_timer()
  state.timer:start(TICK_MS, TICK_MS, vim.schedule_wrap(tick))
end

--- Announce that something is taking time. Safe to call from a coroutine.
---@param id string stable key, so the same activity can be updated or ended
---@param label string human text, without the duration
---@param foreground boolean|nil force this to count as user-requested work
function M.activity(id, label, foreground)
  local existing = state.activities[id]
  if existing then
    existing.label = label or existing.label
    state.rendered = nil
    return
  end
  state.seq = state.seq + 1
  state.activities[id] = {
    label = label,
    started = now(),
    seq = state.seq,
    foreground = foreground or state.requesting or false,
  }
  state.rendered = nil
  vim.schedule(function()
    notify_progress()
    ensure_timer()
  end)
end

--- Mark an activity finished. Unknown ids are ignored, so callers can be blunt.
function M.activity_done(id)
  if not state.activities[id] then
    return
  end
  state.activities[id] = nil
  state.rendered = nil
  if progress_message() == "" then
    vim.schedule(function()
      -- Something else may have started in the meantime.
      if progress_message() == "" then
        hide_progress()
      end
    end)
  end
end

--- Replace the progress notification with a final, self-dismissing message.
--- Ends the request window: whatever runs after this is nobody's request.
function M.announce(message, level, icon)
  level = level or vim.log.levels.INFO
  state.requesting = false
  -- Whatever is still going belonged to the episode that just ended -- a
  -- re-scan triggered by the run, typically. Demote it so it cannot immediately
  -- paint over the result the user is trying to read; if it really is slow it
  -- earns the notification back after PROMOTE_AFTER.
  for _, activity in pairs(state.activities) do
    activity.foreground = false
    activity.promote_from = now()
  end
  state.rendered = nil
  vim.schedule(function()
    state.showing_progress = false
    vim.notify(message, level, {
      id = NOTIFY_ID,
      title = TITLE,
      timeout = level >= vim.log.levels.WARN and 8000 or 4000,
      opts = function(notif)
        notif.icon = icon or notif.icon
      end,
    })
  end)
end

------------------
-- What neotest knows about the current buffer
--
-- Used to turn a bare "No tests found" into something actionable: there is a
-- difference between "this file has 14 tests but none of them is under your
-- cursor" and "nothing in this file was ever discovered".
------------------

---@return string[]
local function adapter_ids()
  local ok, neotest = pcall(require, "neotest")
  if not ok or not neotest.state then
    return {}
  end
  local ok_ids, ids = pcall(neotest.state.adapter_ids)
  return (ok_ids and ids) or {}
end

---@return { adapter: string, total: integer, counts: table }|nil
local function buffer_tests(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ids = adapter_ids()
  if #ids == 0 then
    return nil
  end
  local neotest = require("neotest")
  for _, adapter_id in ipairs(ids) do
    local ok, counts = pcall(neotest.state.status_counts, adapter_id, { buffer = bufnr })
    if ok and counts and counts.total and counts.total > 0 then
      return { adapter = adapter_id, total = counts.total, counts = counts }
    end
  end
  return nil
end

local function no_tests_message()
  local info = buffer_tests()
  if info then
    return string.format("No test at the cursor (%s in this file)", plural(info.total, "test"))
  end
  if #adapter_ids() == 0 then
    return "No tests found — no adapter has claimed this project yet (:TestStatus)"
  end
  return "No tests found in this file (:TestStatus for what was discovered)"
end

------------------
-- neotest consumer
--
-- Registered under our own name so these listeners sit alongside, rather than
-- on top of, the ones the built-in consumers install.
------------------

--- How many of these positions are actual tests (the list also carries the
--- file and its namespaces), and which ids those are.
---
--- Yield-free by construction: passing the adapter id makes `get_position` a
--- plain lookup in client state rather than an adapter search, and `get_key` is
--- a map index. That matters because this runs inside the event listener --
--- if it suspended, the results for a fast test could land before `state.run`
--- existed and the summary would never be shown.
local function count_tests(client, adapter_id, root_id, position_ids)
  local wanted = {}
  for _, id in ipairs(position_ids) do
    wanted[id] = true
  end

  local ok, tree = pcall(client.get_position, client, root_id, { adapter = adapter_id })
  if not ok or not tree then
    return #position_ids, wanted
  end

  local ids, count = {}, 0
  for _, id in ipairs(position_ids) do
    local ok_node, node = pcall(tree.get_key, tree, id)
    if ok_node and node and node:data().type == "test" then
      ids[id] = true
      count = count + 1
    end
  end
  if count == 0 then
    return #position_ids, wanted
  end
  return count, ids
end

local function summarise(results, test_ids)
  local counts = { passed = 0, failed = 0, skipped = 0, total = 0 }
  for id, result in pairs(results) do
    -- Adapters report per test, but neotest's failure path fills in every
    -- position, so filter to the tests we actually asked for.
    if (not next(test_ids)) or test_ids[id] then
      local status = result.status
      if counts[status] ~= nil then
        counts[status] = counts[status] + 1
        counts.total = counts.total + 1
      end
    end
  end
  return counts
end

--- The one place the "Running ..." line is composed. The consumer knows how
--- many tests; the build_spec wrapper knows what command they run in; either
--- may learn its half first.
local function run_label()
  local run = state.run
  if not run then
    return "Running tests"
  end
  local label = string.format("Running %s", plural(run.count, "test"))
  if run.program then
    label = label .. " · " .. run.program
  end
  if run.done > 0 then
    label = label .. string.format(" · %d done", run.done)
  end
  return label
end

local function consumer(client)
  client.listeners.starting = function()
    log("client starting")
    M.activity("startup", "Starting test client")
  end

  client.listeners.started = function()
    M.activity_done("startup")
    log("client started")
  end

  client.listeners.run = function(adapter_id, root_id, position_ids)
    -- A run can also start from the summary window or a watcher, with no
    -- keypress of ours behind it; either way it is the user's doing.
    state.requesting = true
    M.activity_done("request")
    local count, test_ids = count_tests(client, adapter_id, root_id, position_ids)
    if state.run then
      -- A second adapter joining a run already in flight (a suite spanning
      -- dotnet and vitest, say). Fold it in rather than losing the first.
      state.run.count = state.run.count + count
      state.run.test_ids = vim.tbl_extend("force", state.run.test_ids, test_ids)
    else
      state.run = {
        started = now(),
        at = os.date("%H:%M:%S"),
        count = count,
        done = 0,
        test_ids = test_ids,
        adapter = adapter_id,
        results = {},
      }
    end
    log("running %s", plural(count, "test"))
    M.activity("run", run_label(), true)
  end

  client.listeners.results = function(_, results, partial)
    local run = state.run
    if not run then
      return
    end
    run.results = vim.tbl_extend("force", run.results, results)
    if partial then
      local done = summarise(run.results, run.test_ids).total
      if done ~= run.done then
        run.done = done
        M.activity("run", run_label())
      end
      return
    end

    local counts = summarise(run.results, run.test_ids)
    local duration = now() - run.started
    state.summary = vim.tbl_extend("force", counts, {
      duration = duration,
      at = os.date("%H:%M:%S"),
    })
    state.run = nil
    M.activity_done("run")

    local parts = {}
    if counts.passed > 0 then
      parts[#parts + 1] = counts.passed .. " passed"
    end
    if counts.failed > 0 then
      parts[#parts + 1] = counts.failed .. " failed"
    end
    if counts.skipped > 0 then
      parts[#parts + 1] = counts.skipped .. " skipped"
    end

    if #parts == 0 then
      log("run finished with no results")
      M.announce(
        string.format("Run finished with no results · %s (:TestStatus)", fmt_duration(duration)),
        vim.log.levels.WARN,
        "!"
      )
      return
    end

    local message = table.concat(parts, " · ") .. " · " .. fmt_duration(duration)
    log("results: %s", message)
    M.announce(
      message,
      counts.failed > 0 and vim.log.levels.ERROR or vim.log.levels.INFO,
      counts.failed > 0 and "✗" or "✓"
    )
  end
end

------------------
-- Adapter instrumentation -- the language-agnostic layer
--
-- Wrapping the adapter rather than any one plugin's internals means vitest and
-- zig get the same treatment as dotnet. Discovery is aggregated: scanning a
-- repo calls discover_positions once per file, and 400 flickering notifications
-- would be worse than none.
------------------

--- One reusable timer rather than one per call: a directory scan calls through
--- here once per file, and creating and closing a libuv handle each time is
--- real work for something the user never sees.
local function discovery_stop_timer()
  if not state.discovery.stop_timer then
    state.discovery.stop_timer = vim.uv.new_timer()
  end
  return state.discovery.stop_timer
end

local function discovery_label()
  local discovery = state.discovery
  if discovery.files == 0 then
    return "Discovering tests"
  end
  local label = string.format("Discovering tests · %s scanned", plural(discovery.files, "file"))
  if discovery.tests > 0 then
    label = label .. string.format(", %s found", plural(discovery.tests, "test"))
  end
  return label
end

local function discovery_started()
  state.discovery.in_flight = state.discovery.in_flight + 1
  discovery_stop_timer():stop()
  M.activity("discovery", discovery_label())
end

---@param found integer|nil tests found, when the call was a file scan
---@param counted boolean|nil whether this call scanned a file (vs. classified one)
local function discovery_finished(found, counted)
  local discovery = state.discovery
  discovery.in_flight = math.max(0, discovery.in_flight - 1)
  if counted then
    discovery.files = discovery.files + 1
    discovery.tests = discovery.tests + (found or 0)
  end
  M.activity("discovery", discovery_label())
  if discovery.in_flight > 0 then
    return
  end
  -- Debounced: files are scanned by a pool of workers that drains between
  -- batches, and blinking the line off and on again reads as a bug.
  local timer = discovery_stop_timer()
  timer:stop()
  timer:start(
    500,
    0,
    vim.schedule_wrap(function()
      if state.discovery.in_flight == 0 and state.activities["discovery"] then
        M.activity_done("discovery")
        log(
          "discovery idle: %s scanned, %s found",
          plural(state.discovery.files, "file"),
          plural(state.discovery.tests, "test")
        )
      end
    end)
  )
end

--- Concurrency-safe activity keys: neotest may call build_spec and results
--- several times over for one run (one per spec, or one per child position on
--- the broken-down fallback path), and a shared key would let the first one to
--- finish clear the line for all of them.
local activity_uid = 0
local function unique_id(prefix)
  activity_uid = activity_uid + 1
  return string.format("%s:%d", prefix, activity_uid)
end

--- The program a spec will actually run, if it runs one. This is what makes
--- the wait legible without knowing anything about the language: "vitest",
--- "zig", "cargo", "pytest". Adapters that drive the run themselves through a
--- custom strategy (neotest-vstest does) carry no command, and get nothing --
--- their slow phases are reported by their own instrumentation instead.
---@return string|nil
local function spec_program(spec)
  if type(spec) ~= "table" then
    return nil
  end
  -- build_spec may return one spec or a list of them.
  local first = spec.command ~= nil and spec or spec[1]
  local command = type(first) == "table" and first.command or nil
  if type(command) == "string" then
    command = vim.split(command, "%s+", { trimempty = true })
  end
  if type(command) ~= "table" or type(command[1]) ~= "string" then
    return nil
  end
  local program = vim.fs.basename(command[1])
  -- The first word is often only a launcher -- npx, dotnet, go, cargo, zig --
  -- and the word after it is the one that says what is happening. Take it when
  -- it is a subcommand rather than a flag or a path, so this reads "npx vitest"
  -- and "go test" instead of "npx" and "go".
  for i = 2, math.min(#command, 4) do
    local word = command[i]
    if type(word) == "string" and not word:match("^[-.]") and not word:find("/", 1, true) then
      return program .. " " .. word
    end
  end
  return program
end

local function count_tree_tests(tree)
  if not tree or type(tree) ~= "table" or not tree.iter then
    return 0
  end
  local ok, count = pcall(function()
    local n = 0
    for _, position in tree:iter() do
      if position.type == "test" then
        n = n + 1
      end
    end
    return n
  end)
  return ok and count or 0
end

--- Wrap an adapter so its slow entry points report themselves.
--- Returns a proxy: the adapter table itself is shared module state and must
--- not be mutated.
---@param adapter neotest.Adapter
function M.instrument(adapter)
  local wrapped = setmetatable({}, { __index = adapter })
  local name = adapter.name or "adapter"

  if adapter.root then
    wrapped.root = function(path)
      local id = "root:" .. name
      M.activity(id, string.format("%s: locating project root", name))
      local ok, result = pcall(adapter.root, path)
      M.activity_done(id)
      if not ok then
        log("%s: root() failed: %s", name, result)
        error(result, 0)
      end
      return result
    end
  end

  -- For neotest-vstest this is the expensive one: classifying a single .cs file
  -- means resolving its project through msbuild and asking the test host what
  -- it contains. It says nothing per file (there would be hundreds), it just
  -- holds the discovery line open so the phase is visible.
  if adapter.is_test_file then
    wrapped.is_test_file = function(path)
      discovery_started()
      local ok, result = pcall(adapter.is_test_file, path)
      discovery_finished(nil, false)
      if not ok then
        log("%s: is_test_file(%s) failed: %s", name, vim.fs.basename(path), result)
        error(result, 0)
      end
      return result
    end
  end

  if adapter.discover_positions then
    wrapped.discover_positions = function(path)
      discovery_started()
      local ok, result = pcall(adapter.discover_positions, path)
      discovery_finished(ok and count_tree_tests(result) or 0, true)
      if not ok then
        log("%s: discover_positions(%s) failed: %s", name, vim.fs.basename(path), result)
        error(result, 0)
      end
      return result
    end
  end

  -- Assembling the command is usually instant, but not always -- an adapter
  -- that has to ask a test host what exists does it here. Its real value is the
  -- command itself, which turns "Running 12 tests" into "Running 12 tests ·
  -- vitest": the answer to "what am I waiting for" in any language.
  if adapter.build_spec then
    wrapped.build_spec = function(args)
      local id = unique_id("spec:" .. name)
      M.activity(id, string.format("%s: preparing command", name))
      local ok, spec = pcall(adapter.build_spec, args)
      M.activity_done(id)
      if not ok then
        log("%s: build_spec failed: %s", name, spec)
        error(spec, 0)
      end
      local program = spec_program(spec)
      if program and state.run and state.run.program ~= program then
        state.run.program = program
        log("%s: running via %s", name, program)
        M.activity("run", run_label())
      end
      return spec
    end
  end

  -- The gap between the test process exiting and the results appearing: for
  -- adapters that parse a junit XML or a coverage report this is seconds of
  -- apparent nothing, right at the point the user expects an answer.
  if adapter.results then
    wrapped.results = function(spec, result, tree)
      local id = unique_id("results:" .. name)
      M.activity(id, string.format("%s: collecting results", name))
      local ok, results = pcall(adapter.results, spec, result, tree)
      M.activity_done(id)
      if not ok then
        log("%s: results() failed: %s", name, results)
        error(results, 0)
      end
      return results
    end
  end

  return wrapped
end

------------------
-- neotest-vstest instrumentation -- the one adapter-specific layer
--
-- Everything above already reports this adapter like any other. What it cannot
-- see is the work dotnet does behind the adapter interface, and that is where
-- the minutes go. `dotnet build` runs on client
-- start *and* before every single run, and MTP discovery spawns the test host
-- over a socket with a 30s ceiling -- when that ceiling is hit the tests simply
-- are not there, with nothing in the UI to say why.
------------------

local function wrap_dotnet_build()
  local ok, dotnet = pcall(require, "neotest-vstest.dotnet_utils")
  if not ok or rawget(dotnet, "__bh_instrumented") then
    return
  end
  dotnet.__bh_instrumented = true

  local build_path = dotnet.build_path
  dotnet.build_path = function(path)
    local id = "build:" .. path
    local name = vim.fs.basename(path)
    M.activity(id, "Building " .. name)
    local started = now()
    local success = build_path(path)
    local duration = now() - started
    M.activity_done(id)
    log("build %s: %s in %s", name, success and "ok" or "FAILED", fmt_duration(duration))
    if not success then
      M.announce(
        string.format("Build failed: %s (%s) — :TestStatus", name, fmt_duration(duration)),
        vim.log.levels.ERROR,
        "✗"
      )
    end
    return success
  end

  -- Only the first lookup per solution does the work (`dotnet sln list`, then
  -- an msbuild query per project -- minutes on a big one). Everything after it
  -- is a cache hit, and neotest-vstest calls this from filter_dir, i.e. once
  -- per directory of the scan: instrumenting those would cost more than it
  -- reports.
  local get_solution_info = dotnet.get_solution_info
  local inspected = {}
  dotnet.get_solution_info = function(path)
    if inspected[tostring(path)] then
      return get_solution_info(path)
    end
    inspected[tostring(path)] = true
    local id = "solution:" .. tostring(path)
    M.activity(id, "Reading solution " .. vim.fs.basename(tostring(path)))
    local started = now()
    local result = get_solution_info(path)
    M.activity_done(id)
    log(
      "solution %s: %s in %s",
      vim.fs.basename(tostring(path)),
      plural(#((result or {}).projects or {}), "test project"),
      fmt_duration(now() - started)
    )
    return result
  end
end

--- Record what a test binary's discovery actually returned. Zero tests from a
--- project neotest-vstest considered a test project is the TUnit/MTP timeout
--- symptom, and it is otherwise completely silent.
local function record_discovery(dll, count, duration)
  state.discovered[dll] = { count = count, duration = duration, at = os.date("%H:%M:%S") }
  log("%s: %s in %s", vim.fs.basename(dll), plural(count, "test"), fmt_duration(duration))
end

local function wrap_dotnet_discovery()
  local ok_mtp, mtp = pcall(require, "neotest-vstest.mtp.client")
  if ok_mtp and not rawget(mtp, "__bh_instrumented") then
    mtp.__bh_instrumented = true
    local discovery_tests = mtp.discovery_tests
    mtp.discovery_tests = function(dll_path)
      local id = "vstest-discovery:" .. dll_path
      M.activity(id, "Starting test host for " .. vim.fs.basename(dll_path))
      local started = now()
      local tests = discovery_tests(dll_path)
      local duration = now() - started
      M.activity_done(id)
      record_discovery(dll_path, tests and #tests or 0, duration)
      return tests
    end
  end

  local ok_vstest, vstest = pcall(require, "neotest-vstest.vstest.client")
  if ok_vstest and not rawget(vstest, "__bh_instrumented") then
    vstest.__bh_instrumented = true
    local discover_tests_in_project = vstest.discover_tests_in_project
    if discover_tests_in_project then
      vstest.discover_tests_in_project = function(execute, settings, project)
        local dll = (project and project.dll_file) or "test project"
        local id = "vstest-discovery:" .. dll
        M.activity(id, "Starting test host for " .. vim.fs.basename(dll))
        local started = now()
        local cases = discover_tests_in_project(execute, settings, project)
        local duration = now() - started
        M.activity_done(id)
        local count = 0
        for _, per_file in pairs(cases or {}) do
          count = count + vim.tbl_count(per_file)
        end
        record_discovery(dll, count, duration)
        return cases
      end
    end
  end
end

------------------
-- Hardening neotest's own state consumer
--
-- neotest fans an event out to every consumer inside a single coroutine:
--
--   for name, listener in pairs(self.listeners[event] or {}) do listener(...) end
--
-- so the *first* listener that throws takes every listener after it with it,
-- in whatever order `pairs` happened to pick. The built-in state consumer
-- throws on a genuine race: it repopulates its position tree in a debounced
-- background loop (`nio.sleep(50)` per pass), and a "run" event that arrives
-- before the first pass has completed reaches `is_test(pos_id, nil)` and
-- indexes a nil tree.
--
-- The window is small but it sits exactly where it hurts: the first
-- <leader>tt of a session, when discovery has only just finished. When it hits,
-- the run itself proceeds -- the tests do execute -- but the signs, the output
-- panel and our own progress reporting are all silently skipped, which is
-- precisely the "I pressed the key and nothing happened" symptom.
--
-- Two guards, both no-ops once the tree is there: fetch the positions on
-- demand if the background loop has not got to them yet, and treat a missing
-- tree as "not a test" instead of a crash. The counts are recomputed by the
-- next pass of that loop either way.
------------------

local function harden_state_tracker()
  local ok, Tracker = pcall(require, "neotest.consumers.state.tracker")
  if not ok or rawget(Tracker, "__bh_hardened") then
    return
  end
  Tracker.__bh_hardened = true

  local is_test = Tracker.is_test
  function Tracker:is_test(pos_id, tree)
    if not tree then
      return false
    end
    return is_test(self, pos_id, tree)
  end

  local update_running = Tracker.update_running
  function Tracker:update_running(adapter_id, position_ids)
    local adapter_state = self:adapter_state(adapter_id)
    if adapter_state and not adapter_state.positions then
      log("state tracker had no positions yet for %s; fetching", adapter_id:match("^[^:]+") or adapter_id)
      pcall(self.update_positions, self, adapter_id)
    end
    return update_running(self, adapter_id, position_ids)
  end
end

------------------
-- neotest's own messages
--
-- Everything neotest says to the user goes through lib.notify, and it only ever
-- speaks up when it has given up on something. Intercepting it lets the spinner
-- stop with it, and lets "No tests found" say which of the two things it means.
------------------

local function wrap_lib_notify()
  local ok, lib = pcall(require, "neotest.lib")
  if not ok or rawget(lib, "__bh_instrumented") then
    return
  end
  lib.__bh_instrumented = true

  local original = lib.notify
  lib.notify = function(message, level, opts)
    state.last_message = { text = message, level = level or vim.log.levels.INFO, at = os.date("%H:%M:%S") }
    log("neotest: %s", message)
    M.activity_done("request")
    if (level or vim.log.levels.INFO) >= vim.log.levels.WARN then
      M.activity_done("run")
      state.run = nil
      state.requesting = false
    end
    if message == "No tests found" then
      return M.announce(no_tests_message(), vim.log.levels.WARN, "?")
    end
    return original(message, level, opts)
  end
end

------------------
-- Actions
--
-- Wrapping the keymaps is what makes the keypress itself visible: neotest's
-- run() returns immediately and does everything else in a coroutine, so without
-- this there is nothing at all between the keypress and, minutes later, a
-- result.
------------------

local function with_request(label, fn)
  state.requesting = true
  M.activity("request", label, true)
  log("request: %s", label)
  local ok, err = pcall(fn)
  if not ok then
    M.activity_done("request")
    M.announce("Test command failed: " .. tostring(err), vim.log.levels.ERROR, "✗")
  end
end

function M.run_nearest()
  with_request("Finding nearest test", function()
    require("neotest").run.run()
  end)
end

function M.run_file()
  local file = vim.fn.expand("%:p")
  with_request("Collecting tests in " .. vim.fn.fnamemodify(file, ":t"), function()
    require("neotest").run.run(file)
  end)
end

function M.run_all()
  with_request("Collecting all tests", function()
    require("neotest").run.run(vim.uv.cwd())
  end)
end

function M.run_last()
  local neotest = require("neotest")
  local position = neotest.run.get_last_run()
  if not position then
    M.announce("No test has been run yet", vim.log.levels.WARN, "?")
    return
  end
  -- Position ids are "<path>::<namespace>::<test>"; the last segment is the
  -- only part worth putting in a one-line notification.
  with_request("Re-running " .. (position:match("([^:/]+)$") or position), function()
    neotest.run.run_last()
  end)
end

function M.stop()
  -- Deliberately not M.is_busy(): background discovery keeps that true almost
  -- permanently in a dotnet solution, and "nothing is running" has to mean
  -- "no test run of yours is running".
  if not state.run and not state.activities["request"] then
    M.announce("No test run to stop", vim.log.levels.WARN, "?")
    return
  end
  require("neotest").run.stop()
  M.activity_done("request")
  M.announce("Stopping test run", vim.log.levels.WARN, "■")
end

function M.watch_file()
  local neotest = require("neotest")
  local file = vim.fn.expand("%:p")
  neotest.watch.toggle(file)
  local watching = neotest.watch.is_watching(file)
  M.announce(
    string.format("%s %s", watching and "Watching" or "Stopped watching", vim.fn.fnamemodify(file, ":t")),
    vim.log.levels.INFO,
    watching and "👁" or "■"
  )
end

------------------
-- Status line
------------------

--- Text for the lualine component. Deliberately free of statusline escapes:
--- `%*` would reset to the statusline default rather than lualine's section
--- highlight, so the colour is handed over separately via lualine's `color`.
function M.lualine()
  if M.is_busy() then
    local list = active_sorted()
    local current = list[#list]
    -- Drop the duration the label already carries; the statusline is not the
    -- notification and only has room for the headline.
    local label = current.label:gsub("%s*·.*$", "")
    if #label > 28 then
      label = label:sub(1, 27) .. "…"
    end
    return string.format("%s %s %s", spinner_frame(), label, fmt_elapsed(now() - current.started))
  end

  local summary = state.summary
  if not summary then
    return ""
  end
  if summary.failed > 0 then
    return string.format("✗ %d/%d", summary.failed, summary.total)
  end
  if summary.total == 0 then
    return "? no results"
  end
  return string.format("✓ %d", summary.passed)
end

--- Highlight group for the component above. neotest defines these as soon as
--- its config module loads; an unknown group just renders unstyled.
function M.lualine_color()
  if M.is_busy() then
    return "NeotestRunning"
  end
  if not state.summary then
    return nil
  end
  if state.summary.failed > 0 then
    return "NeotestFailed"
  end
  if state.summary.total == 0 then
    return "NeotestSkipped"
  end
  return "NeotestPassed"
end

------------------
-- :TestStatus
------------------

--- Adapter ids are "<name>:<absolute root>", which is most of a screen width
--- of scrollback nobody needs. Keep the name and shorten the path.
local function short_adapter(adapter_id)
  local name, root = adapter_id:match("^([^:]+):(.*)$")
  if not name then
    return adapter_id
  end
  return string.format("%s  %s", name, vim.fn.fnamemodify(root, ":~"))
end

local function report_lines()
  local lines = {}
  local function add(fmt, ...)
    lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  end
  local function section(title)
    if #lines > 0 then
      add("")
    end
    add(title)
  end

  section("Right now")
  local list = active_sorted()
  if #list == 0 then
    add("  idle")
  else
    for _, activity in ipairs(list) do
      add("  %s (%s)", activity.label, fmt_elapsed(now() - activity.started))
    end
  end

  section("Adapters")
  local ok, neotest = pcall(require, "neotest")
  local adapter_ids = {}
  if ok and neotest.state then
    local ok_ids, ids = pcall(neotest.state.adapter_ids)
    adapter_ids = (ok_ids and ids) or {}
  end
  if #adapter_ids == 0 then
    add("  none — neotest has not started, or no adapter claimed this project")
    add("  (run a test once; adapters are resolved lazily)")
  else
    for _, adapter_id in ipairs(adapter_ids) do
      local ok_counts, counts = pcall(neotest.state.status_counts, adapter_id)
      if ok_counts and counts then
        add(
          "  %s\n    %s known · %d passed · %d failed · %d skipped · %d running",
          short_adapter(adapter_id),
          plural(counts.total, "test"),
          counts.passed,
          counts.failed,
          counts.skipped,
          counts.running
        )
      else
        add("  %s", short_adapter(adapter_id))
      end
    end
  end

  section("This buffer")
  local path = vim.fn.expand("%:p")
  add("  %s", path == "" and "(no file)" or vim.fn.fnamemodify(path, ":~:."))
  local info = buffer_tests()
  if info then
    add("  %s discovered via %s", plural(info.total, "test"), info.adapter:match("^[^:]+") or info.adapter)
  else
    add("  no tests discovered here yet")
  end

  if next(state.discovered) then
    section("Test binaries")
    local names = vim.tbl_keys(state.discovered)
    table.sort(names)
    for _, dll in ipairs(names) do
      local entry = state.discovered[dll]
      add(
        "  %-40s %s in %s%s",
        vim.fs.basename(dll),
        plural(entry.count, "test"),
        fmt_duration(entry.duration),
        entry.count == 0 and "   ← nothing came back" or ""
      )
    end
  end

  section("Last run")
  if state.run then
    add("  in progress: %s, %d done", plural(state.run.count, "test"), state.run.done)
  elseif state.summary then
    add(
      "  %s · %d passed · %d failed · %d skipped · %s",
      state.summary.at,
      state.summary.passed,
      state.summary.failed,
      state.summary.skipped,
      fmt_duration(state.summary.duration)
    )
  else
    add("  none this session")
  end

  if state.last_message then
    section("Last message from neotest")
    add("  %s  %s", state.last_message.at, state.last_message.text)
  end

  section("Environment")
  local dotnet = vim.fn.exepath("dotnet")
  add("  dotnet          %s", dotnet ~= "" and dotnet or "not on PATH")
  add("  neotest log     %s", vim.fn.fnamemodify(M.log_path(), ":~"))
  local ok_config, neotest_config = pcall(require, "neotest.config")
  if ok_config then
    local names = { [0] = "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
    add("  log level       %s", names[neotest_config.log_level] or tostring(neotest_config.log_level))
  end

  if #state.events > 0 then
    section("Recent")
    for _, event in ipairs(state.events) do
      add("  %s  %s", event.at, event.text)
    end
  end

  -- Sections above build multi-line strings; flatten so the float gets one
  -- buffer line per display line.
  local flat = {}
  for _, line in ipairs(lines) do
    for _, part in ipairs(vim.split(line, "\n", { plain = true })) do
      flat[#flat + 1] = part
    end
  end
  return flat
end

function M.log_path()
  local ok, dir = pcall(vim.fn.stdpath, "log")
  if not ok then
    dir = vim.fn.stdpath("cache")
  end
  return vim.fs.joinpath(dir, "neotest.log")
end

function M.report()
  vim.lsp.util.open_floating_preview(report_lines(), "", {
    border = "rounded",
    max_width = 100,
    max_height = 40,
    focus_id = "bh-test-status",
    title = " test status ",
    wrap = false,
  })
end

function M.open_log()
  local path = M.log_path()
  if vim.fn.filereadable(path) == 0 then
    M.announce("No neotest log at " .. path, vim.log.levels.WARN, "?")
    return
  end
  vim.cmd.tabedit(vim.fn.fnameescape(path))
  vim.cmd("normal! G")
end

------------------
-- Wiring
------------------

--- The consumer table handed to neotest.setup(). Named so it gets its own
--- listener slots rather than replacing a built-in consumer's.
function M.consumers()
  return { bh_feedback = consumer }
end

--- Install the wrappers that need the vstest plugin to be loaded. Called from
--- the neotest config function, once the adapters have been required.
function M.setup()
  harden_state_tracker()
  wrap_lib_notify()
  wrap_dotnet_build()
  wrap_dotnet_discovery()

  vim.api.nvim_create_user_command("TestStatus", function()
    M.report()
  end, { desc = "Report what the test runner is doing" })

  vim.api.nvim_create_user_command("TestLog", function()
    M.open_log()
  end, { desc = "Open the neotest log" })
end

return M
