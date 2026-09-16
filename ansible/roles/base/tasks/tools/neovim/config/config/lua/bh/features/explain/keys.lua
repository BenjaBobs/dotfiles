-- `gK` explains the literal under the cursor (see bh/explain.lua).
--
-- It sits next to its two relatives rather than on the leader: `K` is the LSP
-- hover for symbols, `ga` is the built-in character-code readout, and `gK` is
-- the same reflex for encoded values. Deliberately *not* folded into `K` --
-- that key carries the customised LSP hover and the Roslyn response patching
-- in bh/plugins/lsp.lua, which is not worth destabilising for this.
vim.keymap.set({ "n", "x" }, "gK", function()
  require("bh.features.explain").explain()
end, { desc = "Explain literal under cursor" })
