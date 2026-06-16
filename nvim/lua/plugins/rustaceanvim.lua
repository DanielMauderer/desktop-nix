return {
	{
		"mrcjkb/rustaceanvim",
		version = "^5",
		lazy = false,
		dependencies = { "saghen/blink.cmp" },
		config = function()
			vim.g.rustaceanvim = function()
				return {
					server = {
						capabilities = require("blink.cmp").get_lsp_capabilities(),
						settings = function(project_root, default_settings)
							local settings = vim.tbl_deep_extend("force", default_settings, {
								["rust-analyzer"] = {
									checkOnSave = true,
									check = { command = "clippy" },
									cargo = { allFeatures = true },
									procMacro = { enable = true },
									diagnostics = {
										enable = true,
										experimental = { enable = true },
									},
								},
							})
							-- Per-project overrides: deep-merge a `rust-analyzer.json`
							-- from the project root if one exists. Lets no_std/embedded
							-- repos restrict checking to `--bins` without affecting
							-- the global defaults above.
							--
							-- SECURITY: rust-analyzer settings can carry keys that run
							-- arbitrary commands on open/save (check.overrideCommand,
							-- cargo.buildScripts.overrideCommand, procMacro, runnables).
							-- A hostile cloned repo could ship a malicious file, so we
							-- read it through vim.secure.read — which prompts once per
							-- file and records the trust decision. Untrusted/declined
							-- files return nil and are ignored.
							local override = project_root .. "/rust-analyzer.json"
							if vim.uv.fs_stat(override) then
								local contents = vim.secure.read(override)
								if contents then
									local ok, data = pcall(vim.json.decode, contents)
									if ok and type(data) == "table" then
										settings = vim.tbl_deep_extend("force", settings, data)
									end
								end
							end
							return settings
						end,
					},
					dap = {
						adapter = {
							type = "executable",
							command = "gdb",
							args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
							name = "gdb",
						},
					},
				}
			end
		end,
		keys = {
			{
				"<leader>rr",
				function()
					vim.cmd.RustLsp("runnables")
				end,
				desc = "[R]ust runnables",
				ft = "rust",
			},
			{
				"<leader>rd",
				function()
					vim.cmd.RustLsp("debuggables")
				end,
				desc = "Rust [d]ebuggables",
				ft = "rust",
			},
			{
				"<leader>rm",
				function()
					vim.cmd.RustLsp("expandMacro")
				end,
				desc = "Rust expand [m]acro",
				ft = "rust",
			},
			{
				"<leader>re",
				function()
					vim.cmd.RustLsp("explainError")
				end,
				desc = "Rust [e]xplain error",
				ft = "rust",
			},
		},
	},
}
