return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- Setup dap-ui
			dapui.setup()

			-- Auto-open/close dap-ui when debugging starts/ends
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
		keys = {
			{
				"<leader>d",
				group = "Debugger",
				nowait = true,
				remap = false,
			},
			-- Debug control
			{
				"<F5>",
				function()
					require("dap").continue()
				end,
				desc = "Debug: Start/Continue",
			},
			{
				"<F10>",
				function()
					require("dap").step_over()
				end,
				desc = "Debug: Step Over",
			},
			{
				"<F11>",
				function()
					require("dap").step_into()
				end,
				desc = "Debug: Step Into",
			},
			{
				"<F12>",
				function()
					require("dap").step_out()
				end,
				desc = "Debug: Step Out",
			},

			-- Breakpoint management lives in persistent-breakpoints.lua.

			-- DAP UI controls
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "Debug: Toggle UI",
			},
			{
				"<leader>de",
				function()
					require("dapui").eval()
				end,
				desc = "Debug: Evaluate Expression",
				mode = { "n", "v" },
			},
			{
				"<leader>df",
				function()
					require("dapui").float_element()
				end,
				desc = "Debug: Float Element",
			},

			-- Session management
			{
				"<leader>dr",
				function()
					require("dap").repl.open()
				end,
				desc = "Debug: Open REPL",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Debug: Run Last",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Debug: Terminate Session",
			},
			{
				"<leader>dR",
				function()
					require("dap").restart()
				end,
				desc = "Debug: Restart Session",
			},

			-- Utility
			{
				"<leader>dh",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "Debug: Hover Variables",
			},
			{
				"<leader>ds",
				function()
					local widgets = require("dap.ui.widgets")
					widgets.centered_float(widgets.scopes)
				end,
				desc = "Debug: Show Scopes",
			},
		},
	},
}
