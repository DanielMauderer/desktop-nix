return {
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons", { "junegunn/fzf", build = "./install --bin" } },
		-- Lazy-load on its keymaps (NV-ST-3); the FzfLua global is set when the
		-- plugin loads, before any of the key handlers below run.
		opts = {
			-- Override default key mappings to prevent Ctrl+D from exiting
			keymap = {
				fzf = {
					-- Disable Ctrl+D exit behavior, keep it as half page down only
					["ctrl-d"] = "half-page-down",
					-- You can also disable Ctrl+U exit if needed
					["ctrl-u"] = "half-page-up",
				},
			},
		},
		keys = {
			{
				"<leader>sr",
				function()
					FzfLua.registers()
				end,
				desc = "[S]earch [R]egisters",
			},
			{
				"<leader>z",
				function()
					FzfLua.zoxide()
				end,
				desc = "Jump with [Z]oxide",
			},
			{
				"<leader>Rg", -- ripgrep in selected directory
				function()
					-- First use fzf-lua to select a directory
					require("fzf-lua").files({
						prompt = "Select Directory> ",
						cmd = "find . -type d -maxdepth 5 2>/dev/null",
						file_icons = false,
						actions = {
							["default"] = function(selected, _opts)
								local dir = selected[1]
								if dir then
									local path = dir
									require("fzf-lua").live_grep({
										search_paths = { path },
										prompt = "Rg in " .. path .. "> ",
									})
								else
									print("No directory selected")
								end
							end,
						},
					})
				end,
				desc = "Ripgrep in selected directory",
			},
		},
	},
}
