local keymap = vim.keymap

return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"rouge8/neotest-rust",
		"nvim-neotest/neotest-go",
        'llllvvuu/neotest-foundry',
	},
	config = function()
		require("neotest").setup({
			adapters = {
				require("neotest-rust")({
					args = { "--no-capture" },
				}),
				require("neotest-go"),
                require('neotest-foundry')
			},
		})
	end,
	lazy = false,
	keys = {
		keymap.set("n", "<leader>tr", ":Neotest run<CR>"),
		keymap.set("n", "<leader>tf", ":Neotest run file<CR>"),
		keymap.set("n", "<leader>tl", ":Neotest run last<CR>"),
		keymap.set("n", "<leader>to", ":Neotest output<CR>"),

		keymap.set("n", "<leader>tz", ":Neotest output-panel toggle<CR>"),
		keymap.set("n", "<leader>ts", ":Neotest summary toggle<CR>"),

		keymap.set("n", "<leader>tn", ":Neotest jump next<CR>"),
		keymap.set("n", "<leader>tp", ":Neotest jump prev<CR>"),
	},
}
