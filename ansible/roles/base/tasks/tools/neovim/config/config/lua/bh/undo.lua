------------------
-- Undo/redo on <C-z>/<C-S-z> instead of u/<C-r>.
--
-- `u` sits right next to `i`, and unlike most mis-hits it silently changes the
-- buffer instead of doing nothing, so it's unmapped rather than left as a trap.
--
-- Ghostty speaks the kitty keyboard protocol, which is what makes <C-S-z>
-- distinguishable from <C-z> at all -- a plain terminal sends 0x1A for both.
-- Note that <C-Z> is *not* a valid spelling of ctrl+shift+z: Vim keynotation
-- treats <C-Z> and <C-z> as the same key, so the shift has to be explicit.
--
-- <C-z> normally suspends Nvim; use `:sus` if you want that.
------------------

-- `U` goes too: in normal mode it's "undo all changes on the last changed line",
-- which is both rarely wanted and more destructive than a single undo -- and
-- it's shift plus the key being disabled here, so it's the same fat-finger.
--
-- Both are also disabled in visual mode, where `u`/`U` are the lower/uppercase
-- operators rather than undo. `gu{motion}`/`gU{motion}` (guiw, gUU, ...) still
-- do that job from normal mode.
for _, lhs in ipairs({ "u", "U" }) do
  vim.keymap.set({ "n", "x" }, lhs, "<Nop>", { noremap = true, silent = true, desc = "Disabled - use <C-z> to undo" })
end

-- `noremap` matters here: it makes the right-hand side the *builtin* u/<C-r>
-- rather than resolving through the <Nop> above. Counts still work, so
-- 3<C-z> undoes three changes.
vim.keymap.set("n", "<C-z>", "u", { noremap = true, silent = true, desc = "Undo" })
vim.keymap.set("n", "<C-S-z>", "<C-r>", { noremap = true, silent = true, desc = "Redo" })

------------------
-- Persistent undo, plus the pruning Nvim doesn't do for us.
--
-- `:h undo-persistence`: "undo files are never deleted by Vim. You need to
-- delete them yourself." Left alone, ~/.local/state/nvim/undo grows forever, and
-- every file in it holds text that was deleted from the real file -- so stale
-- entries are both clutter and a small data-at-rest concern.
--
-- An undo file's mtime is the last time that buffer was written, so mtime is
-- exactly "when did I last touch this file".
------------------

local M = {}

local PRUNE_AFTER_DAYS = 30
local PRUNE_EVERY_HOURS = 24

local uv = vim.uv
local stamp_path = vim.fs.joinpath(vim.fn.stdpath("state"), "undo-prune-stamp")

vim.opt.undofile = true

-- 'undodir' is a comma-separated list, and Nvim writes to the first entry that
-- exists, so that is the only one worth scanning. "." means "next to the edited
-- file", which we deliberately don't touch.
local function undo_dir()
  for entry in vim.gsplit(vim.o.undodir, ",", { plain = true, trimempty = true }) do
    local dir = vim.trim(entry):gsub("/+$", "")
    if dir ~= "" and dir ~= "." and uv.fs_stat(dir) then
      return dir
    end
  end
end

--- Delete undo files not written in the last PRUNE_AFTER_DAYS days.
--- @param opts? { dry_run?: boolean }
--- @return integer removed, integer failed, string? dir
function M.prune(opts)
  opts = opts or {}
  local dir = undo_dir()
  if not dir then
    return 0, 0, nil
  end

  local scanner = uv.fs_scandir(dir)
  if not scanner then
    return 0, 0, dir
  end

  local cutoff = os.time() - PRUNE_AFTER_DAYS * 24 * 60 * 60
  local removed, failed = 0, 0

  while true do
    local name = uv.fs_scandir_next(scanner)
    if not name then
      break
    end

    -- Never recurse, and only ever unlink plain files. Everything in a dedicated
    -- undodir is Nvim's, so there's nothing else in here to be careful about.
    local path = vim.fs.joinpath(dir, name)
    local stat = uv.fs_stat(path)
    if stat and stat.type == "file" and stat.mtime.sec < cutoff then
      if opts.dry_run or uv.fs_unlink(path) then
        removed = removed + 1
      else
        failed = failed + 1
      end
    end
  end

  return removed, failed, dir
end

vim.api.nvim_create_user_command("UndoPrune", function(cmd)
  local removed, failed, dir = M.prune({ dry_run = cmd.bang })
  if not dir then
    vim.notify("No undo directory to prune", vim.log.levels.WARN)
    return
  end
  local verb = cmd.bang and "would remove" or "removed"
  local msg = ("%s %d undo file(s) older than %d days in %s"):format(verb, removed, PRUNE_AFTER_DAYS, dir)
  if failed > 0 then
    msg = msg .. (" (%d could not be deleted)"):format(failed)
  end
  vim.notify(msg, failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end, { bang = true, desc = "Prune old undo files (! to preview without deleting)" })

-- Rate-limited to once a day via the stamp file's own mtime, and deferred past
-- startup so a directory scan never shows up in startup time.
local function prune_is_due()
  local stat = uv.fs_stat(stamp_path)
  return not stat or (os.time() - stat.mtime.sec) > PRUNE_EVERY_HOURS * 60 * 60
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  desc = "Prune stale undo files in the background",
  callback = function()
    if not prune_is_due() then
      return
    end
    vim.defer_fn(function()
      local _, failed = M.prune()
      local fd = uv.fs_open(stamp_path, "w", tonumber("644", 8))
      if fd then
        uv.fs_close(fd)
      end
      -- Silent on success; a startup notification for routine housekeeping is
      -- just noise. Use :UndoPrune if you want to see the count.
      if failed > 0 then
        vim.notify(("Failed to delete %d stale undo file(s)"):format(failed), vim.log.levels.WARN)
      end
    end, 3000)
  end,
})

return M
