return {
  'nvim-telescope/telescope.nvim', tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
	  local builtin = require 'telescope.builtin'
	  vim.keymap.set('n', '<leader>ps', builtin.find_files, { desc = '[S]earch Files' })
	  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
  end
}
