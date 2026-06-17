return {
	{
		"theHamsta/nvim-dap-virtual-text",
		opts = {},
	},
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		-- DAP adapters (gdb, js-debug-adapter) come from Nix (home.packages); the
		-- Mason stack was removed (DECISIONS 047) as it installed nothing.
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
		},
		config = function()
			local dap = require("dap")

			-- ── Adapters ────────────────────────────────────────────────────────

			dap.adapters.gdb = {
				type = "executable",
				command = "gdb",
				args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
			}

			dap.adapters["pwa-node"] = {
				type = "server",
				host = "::1",
				port = "${port}",
				executable = {
					command = "js-debug-adapter",
					args = { "${port}" },
				},
			}

			-- ── Helpers ─────────────────────────────────────────────────────────

			local binary_picker = function()
				local co = coroutine.running()
				vim.schedule(function()
					local cwd = vim.fn.getcwd()
					local handle = io.popen(
						"find " .. vim.fn.shellescape(cwd) .. " -type f -executable | grep -v .git 2>/dev/null"
					)
					local items = {}
					if handle then
						for line in handle:lines() do
							table.insert(items, { file = line, text = line:gsub(cwd .. "/", "") })
						end
						handle:close()
					end
					require("snacks").picker.pick({
						title = "Select Executable",
						items = items,
						format = function(item)
							return { { item.text, "Normal" } }
						end,
						confirm = function(picker, item)
							picker:close()
							if item then
								coroutine.resume(co, item.file)
							end
						end,
					})
				end)
				return coroutine.yield()
			end

			local cargo_target_picker = function()
				local co = coroutine.running()
				vim.schedule(function()
					local handle = io.popen("cargo metadata --no-deps --format-version 1 2>/dev/null")
					local items = {}
					if handle then
						local output = handle:read("*a")
						handle:close()
						local ok, metadata = pcall(vim.json.decode, output)
						if ok and metadata then
							for _, package in ipairs(metadata.packages or {}) do
								for _, target in ipairs(package.targets or {}) do
									local kind = target.kind and target.kind[1]
									if kind == "bin" then
										table.insert(items, {
											kind = "bin",
											name = target.name,
										})
									elseif kind == "example" then
										table.insert(items, {
											kind = "example",
											name = target.name,
										})
									end
								end
							end
						end
					end
					require("snacks").picker.pick({
						title = "Select Cargo Target",
						items = items,
						format = function(item)
							return { { string.format("%s - %s", item.kind, item.name), "Normal" } }
						end,
						confirm = function(picker, item)
							picker:close()
							if item then
								coroutine.resume(co, item)
							end
						end,
					})
				end)

				local pick = coroutine.yield() -- .kind and .name
				vim.notify(
					string.format("Build command:\ncargo build --%s %s", pick.kind, pick.name),
					vim.log.levels.INFO
				)
				local handle = io.popen(
					string.format(
						"cargo build --%s %s --message-format json 2>/dev/null | jq -r .executable | grep /",
						pick.kind,
						vim.fn.shellescape(pick.name)
					)
				)
				if not handle then
					vim.notify("Failed to start cargo build", vim.log.levels.ERROR)
					return nil
				end
				local output = handle:read("*a")
				local ok, _, code = handle:close()
				if not ok then
					vim.notify(string.format("Cargo build failed (exit %d)", code), vim.log.levels.ERROR)
					return nil
				end

				local path = vim.trim(output)
				vim.notify(string.format("Binary compiled to:\n%s", path), vim.log.levels.INFO)
				return path
			end

			local ts_skip_files = { "<node_internals>/**", "**/node_modules/**" }
			local ts_source_maps = {
				sourceMaps = true,
				resolveSourceMapLocations = {
					"${workspaceFolder}/**",
					"!**/node_modules/**",
				},
			}

			-- ── C / C++ / Rust ───────────────────────────────────────────────────

			dap.configurations.c = {
				{
					name = "Launch",
					type = "gdb",
					request = "launch",
					program = binary_picker,
					args = {},
					cwd = "${workspaceFolder}",
					stopAtBeginningOfMainSubprogram = false,
				},
				{
					name = "Select and attach to process",
					type = "gdb",
					request = "attach",
					program = binary_picker,
					pid = function()
						local name = vim.fn.input("Executable name (filter): ")
						return require("dap.utils").pick_process({ filter = name })
					end,
					cwd = "${workspaceFolder}",
				},
				{
					name = "Attach to gdbserver :1234",
					type = "gdb",
					request = "attach",
					target = "localhost:1234",
					program = binary_picker,
					cwd = "${workspaceFolder}",
				},
			}

			dap.configurations.cpp = dap.configurations.c
			dap.configurations.rust = {
				{
					name = "Cargo target",
					type = "gdb",
					request = "launch",
					program = cargo_target_picker,
					cwd = "${workspaceFolder}",
					stopAtBeginningOfMainSubprogram = false,
				},
			}

			-- ── TypeScript / JavaScript ──────────────────────────────────────────

			dap.configurations.typescript = {
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch with tsx",
					runtimeExecutable = "tsx",
					program = "${file}",
					cwd = "${workspaceFolder}",
					sourceMaps = ts_source_maps.sourceMaps,
					resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
					skipFiles = ts_skip_files,
				},
				{
					type = "pwa-node",
					request = "launch",
					name = "Launch npm script",
					runtimeExecutable = "npm",
					runtimeArgs = function()
						local script = vim.fn.input("Script: ", "start")
						return { "run", script }
					end,
					cwd = "${workspaceFolder}",
					sourceMaps = ts_source_maps.sourceMaps,
					resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
					skipFiles = ts_skip_files,
				},
				{
					type = "pwa-node",
					request = "attach",
					name = "Attach to process",
					processId = require("dap.utils").pick_process,
					cwd = "${workspaceFolder}",
					sourceMaps = ts_source_maps.sourceMaps,
					resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
					skipFiles = ts_skip_files,
				},
				{
					type = "pwa-node",
					request = "attach",
					name = "Attach to port",
					port = function()
						return tonumber(vim.fn.input("Port: ", "9229"))
					end,
					cwd = "${workspaceFolder}",
					sourceMaps = ts_source_maps.sourceMaps,
					resolveSourceMapLocations = ts_source_maps.resolveSourceMapLocations,
					skipFiles = ts_skip_files,
				},
			}

			dap.configurations.javascript = dap.configurations.typescript

			-- Better signs
			vim.fn.sign_define("DapBreakpoint", {
				text = "", -- the symbol shown in the gutter
				texthl = "DapBreakpoint",
				linehl = "",
				numhl = "",
			})

			vim.fn.sign_define("DapBreakpointCondition", {
				text = "◆",
				texthl = "DapBreakpointCondition",
				linehl = "",
				numhl = "",
			})

			vim.fn.sign_define("DapLogPoint", {
				text = "◎",
				texthl = "DapLogPoint",
				linehl = "",
				numhl = "",
			})

			vim.fn.sign_define("DapBreakpointRejected", {
				text = "✗",
				texthl = "DapBreakpointRejected",
				linehl = "",
				numhl = "",
			})

			vim.cmd([[
				highlight DapBreakpoint guifg=#FF5370 guibg=NONE
				highlight DapBreakpointCondition guifg=#FFCB6B guibg=NONE
				highlight DapLogPoint guifg=#82AAFF guibg=NONE
				highlight DapBreakpointRejected guifg=#F07178 guibg=NONE
			]])
		end,
	},
}
