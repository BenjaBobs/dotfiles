------------------
-- `<leader>ct` -- transform the selection (or the buffer) through a picker.
--
-- Sibling to bh/explain.lua: that one *reads* an encoded value, this one
-- *rewrites* it. Same instinct, opposite direction.
--
-- The picker only offers transforms that actually apply. Every entry in the
-- catalogue is run against the input up front, and anything that fails --
-- "YAML → JSON" on a buffer that is not YAML -- never appears. So the list is
-- a statement about your text, and each preview is the literal result of
-- picking that row rather than a description of it.
--
-- The transforms themselves live in catalog.lua; this file is only the
-- machinery and should not need editing to add one.
------------------

local M = {}

-- Extra transforms registered at runtime, for one-offs that do not warrant a
-- line in the catalogue: require("bh.features.transform").add({ name=..., run=... }).
local extra = {}

--- @param t table `{ name, ft, run }` -- see catalog.lua for the contract.
function M.add(t)
  vim.validate("name", t.name, "string")
  vim.validate("run", t.run, "function")
  t.ft = t.ft or "text"
  table.insert(extra, t)
end

local function all()
  return vim.list_extend(vim.list_slice(require("bh.features.transform.catalog"), 1), extra)
end

------------------
-- Input region
------------------

-- The text plus the buffer range to write back to. A visual selection
-- transforms in place; with no selection the whole buffer is the subject,
-- which is what you want for "reformat this JSON file".
local function region()
  local buf = vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode
  if mode:match("^[vV\22]") then
    local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
    if a[2] > b[2] or (a[2] == b[2] and a[3] > b[3]) then
      a, b = b, a
    end
    local ok, lines = pcall(vim.fn.getregion, a, b, { type = mode })
    if ok and lines then
      -- Leave visual mode so the marks settle before the picker takes focus.
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      local linewise = mode == "V"
      return {
        buf = buf,
        text = table.concat(lines, "\n"),
        linewise = linewise,
        srow = a[2] - 1,
        scol = linewise and 0 or a[3] - 1,
        erow = b[2] - 1,
        ecol = linewise and -1 or b[3],
        label = linewise and (#lines .. " lines") or "selection",
      }
    end
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return {
    buf = buf,
    text = table.concat(lines, "\n"),
    linewise = true,
    srow = 0,
    scol = 0,
    erow = #lines - 1,
    ecol = -1,
    label = "buffer",
  }
end

local function replace(r, text)
  local lines = vim.split(text, "\n", { plain = true })
  if r.linewise then
    vim.api.nvim_buf_set_lines(r.buf, r.srow, r.erow + 1, false, lines)
  else
    vim.api.nvim_buf_set_text(r.buf, r.srow, r.scol, r.erow, r.ecol, lines)
  end
end

------------------
-- Entry point
------------------

--- Does this transform apply to `text`?
---
--- `supported` is either a predicate function, or -- as sugar for the common
--- case where applicability is purely the text's shape -- a Lua pattern, or a
--- list of patterns that must all match. A transform with no `supported` at all
--- is offered for any input.
---
--- This runs before `run`, so a transform that shells out never pays for input
--- it was always going to decline. `run` can still return nil for anything the
--- check cannot know in advance.
--- @param tr table a catalogue entry
--- @param text string
function M.applies(tr, text)
  local sup = tr.supported
  if sup == nil then
    return true
  end
  if type(sup) == "function" then
    local ok, res = pcall(sup, text)
    return ok and res and true or false
  end
  for _, pat in ipairs(type(sup) == "table" and sup or { sup }) do
    local ok, found = pcall(string.find, text, pat)
    if not ok or not found then
      return false
    end
  end
  return true
end

--- Build the picker items for `text`. Exposed so the test suite can exercise
--- the catalogue without opening a window.
--- @return table[] items, each `{ text = name, result = string, ft = string }`
function M.candidates(text)
  -- Transforms that had to recognise something about the input come first;
  -- the ones that apply to any text at all sink below them. Two passes rather
  -- than a sort, because table.sort is not stable and catalogue order is
  -- meaningful within each group.
  local specific, universal = {}, {}
  for _, tr in ipairs(all()) do
    local ok, out = false, nil
    if M.applies(tr, text) then
      ok, out = pcall(tr.run, text)
    end
    if ok and out and out ~= "" and out ~= text then
      table.insert(tr.universal and universal or specific, {
        text = tr.name,
        result = out,
        ft = tr.ft,
        preview = { text = out, ft = tr.ft },
      })
    end
  end

  local items = vim.list_extend(specific, universal)
  for i, item in ipairs(items) do
    item.idx = i
  end
  return items
end

function M.open()
  local r = region()
  if vim.trim(r.text) == "" then
    vim.notify("Nothing to transform", vim.log.levels.INFO, { title = "transform" })
    return
  end

  local items = M.candidates(r.text)
  if #items == 0 then
    vim.notify("No transform applies to this " .. r.label, vim.log.levels.INFO, { title = "transform" })
    return
  end

  return Snacks.picker.pick({
    items = items,
    preview = "preview",
    title = "Transform " .. r.label,
    format = function(item)
      return { { item.text, "SnacksPickerLabel" } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        replace(r, item.result)
      end
    end,
    actions = {
      transform_yank = function(picker, item)
        picker:close()
        if item then
          vim.fn.setreg('"', item.result)
          vim.fn.setreg("+", item.result)
          vim.notify("Yanked: " .. item.text, vim.log.levels.INFO, { title = "transform" })
        end
      end,
      transform_scratch = function(picker, item)
        picker:close()
        if item then
          vim.cmd("enew")
          vim.bo.buftype = "nofile"
          vim.bo.bufhidden = "wipe"
          vim.bo.filetype = item.ft
          vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(item.result, "\n", { plain = true }))
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-y>"] = { "transform_yank", mode = { "i", "n" } },
          ["<C-n>"] = { "transform_scratch", mode = { "i", "n" } },
        },
      },
    },
  })
end

return M
