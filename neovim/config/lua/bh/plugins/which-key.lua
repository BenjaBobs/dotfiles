return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
	},
	keys = {
		{
			"<leader>?",

			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
	config = function()
		local wk = require("which-key")
		wk.add({
			{ "<leader>f", group = "[F]ind", icon = { icon = "🔍" } },
			{ "<leader>b", group = "[B]uffer", icon = { icon = "" } },
			{ "<leader>c", group = "[C]ode", icon = { icon = "" } },
		})

		vim.keymap.set("n", "<leader>fb", ":Ex<CR>", { desc = "[B]rowse files" })

		-- Move current line or selected lines up
		vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { noremap = true, silent = true })
		vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { noremap = true, silent = true })

		-- Move selected lines up or down in visual mode
		vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
		vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
	end,
}
