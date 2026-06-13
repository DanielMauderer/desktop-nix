local M = {}

-- Cache for server status to avoid repeated API calls
local server_cache = {}
local cache_timeout = 1000 -- 1 second

-- Utility functions
local function get_lsp_clients()
	local clients = vim.lsp.get_clients()
	local client_map = {}
	for _, client in ipairs(clients) do
		client_map[client.name] = client
	end
	return client_map
end

local function get_available_servers()
	-- On NixOS, LSP servers come from Nix packages (home.packages), not Mason.
	-- Return the servers explicitly configured in nvim-lspconfig.lua instead of
	-- querying Mason's empty install registry.
	return { "lua_ls", "gopls", "clangd", "html", "cssls", "jsonls", "yamlls" }
end

local function get_server_status(server_name)
	-- Check cache first
	local now = vim.uv.now()
	if server_cache[server_name] and (now - server_cache[server_name].timestamp) < cache_timeout then
		return server_cache[server_name].status, server_cache[server_name].icon, server_cache[server_name].description
	end

	local clients = get_lsp_clients()
	local client = clients[server_name]

	if not client then
		local status, icon, description = "stopped", "●", "Not running"
		server_cache[server_name] = {
			status = status,
			icon = icon,
			description = description,
			timestamp = now,
		}
		return status, icon, description
	end

	-- Check if attached to current buffer
	local bufnr = vim.api.nvim_get_current_buf()
	local is_attached = false

	-- Get clients attached to current buffer
	local buf_clients = vim.lsp.get_clients({ bufnr = bufnr })
	for _, buf_client in ipairs(buf_clients) do
		if buf_client.name == server_name then
			is_attached = true
			break
		end
	end

	local status, icon, description
	if is_attached then
		status, icon, description = "running", "●", "Running & Attached"
	else
		status, icon, description = "running", "●", "Running"
	end

	-- Cache the result
	server_cache[server_name] = {
		status = status,
		icon = icon,
		description = description,
		timestamp = now,
	}

	return status, icon, description
end

local function start_server(server_name)
	-- Use the native config registered via vim.lsp.config() (see
	-- plugins/nvim-lspconfig.lua), falling back to the lsp/<name>.lua that
	-- nvim-lspconfig ships. (The old require("lspconfig")[name].setup{} path is
	-- deprecated and bypasses our registered per-server settings.)
	local config = vim.lsp.config[server_name]

	if not config then
		vim.notify("Server " .. server_name .. " has no vim.lsp.config entry", vim.log.levels.ERROR)
		return false
	end

	-- Check if server is already running
	local clients = get_lsp_clients()
	if clients[server_name] then
		vim.notify("Server " .. server_name .. " is already running", vim.log.levels.INFO)
		return true
	end

	-- Enable it natively — respects the settings/capabilities from vim.lsp.config()
	-- and attaches to matching open buffers.
	local success = pcall(vim.lsp.enable, server_name)

	if success then
		vim.notify("Started LSP server: " .. server_name, vim.log.levels.INFO)
		-- Clear cache for this server since status changed
		server_cache[server_name] = nil
		return true
	else
		vim.notify("Failed to start LSP server: " .. server_name, vim.log.levels.ERROR)
		return false
	end
end

local function stop_server(server_name)
	-- Prevent automatic re-attach on the next matching buffer.
	pcall(vim.lsp.enable, server_name, false)

	local clients = get_lsp_clients()
	local client = clients[server_name]

	if not client then
		vim.notify("Server " .. server_name .. " is not running", vim.log.levels.INFO)
		return false
	end

	-- Stop the running client
	client:stop()
	vim.notify("Stopped LSP server: " .. server_name, vim.log.levels.INFO)
	-- Clear cache for this server since status changed
	server_cache[server_name] = nil
	return true
end

local function toggle_server(server_name)
	local clients = get_lsp_clients()
	local client = clients[server_name]

	if client then
		return stop_server(server_name)
	else
		return start_server(server_name)
	end
end

-- Main picker function
function M.open_lsp_picker()
	local servers = get_available_servers()
	local items = {}

	for _, server_name in ipairs(servers) do
		local status, icon, description = get_server_status(server_name)
		local item = {
			name = server_name,
			status = status,
			icon = icon,
			description = description,
			action = function()
				toggle_server(server_name)
			end,
		}
		table.insert(items, item)
	end

	-- Sort items: running servers first, then alphabetically
	table.sort(items, function(a, b)
		if a.status == "running" and b.status ~= "running" then
			return true
		elseif a.status ~= "running" and b.status == "running" then
			return false
		else
			return a.name < b.name
		end
	end)

	-- Format items for snacks picker
	local formatted_items = {}
	for _, item in ipairs(items) do
		local status_color = item.status == "running" and "green" or "red"
		local display_name = string.format("%s %s", item.icon, item.name)
		local display_description = string.format("[%s] %s", item.status:upper(), item.description)

		table.insert(formatted_items, {
			name = display_name,
			description = display_description,
			action = item.action,
			status = item.status,
			server_name = item.name, -- Store the original server name
		})
	end

	-- Use Snacks picker.select for vim.ui.select
	local Snacks = require("snacks")

	-- Format items for vim.ui.select
	local select_items = {}
	for _, item in ipairs(formatted_items) do
		table.insert(select_items, {
			name = item.name,
			description = item.description,
			action = item.action,
			status = item.status,
			server_name = item.server_name, -- Pass through the original server name
		})
	end

	-- Use vim.ui.select with Snacks picker configuration
	-- Note: vim.ui.select doesn't support custom highlighting for individual items
	-- The Snacks picker will automatically style this with its theme
	vim.ui.select(select_items, {
		prompt = "LSP Language Servers:",
		format_item = function(item)
			local devicons = require("nvim-web-devicons")
			local server_to_filetype = {
				-- Common servers from your setup
				lua_ls = "lua",
				rust_analyzer = "rs",
				ts_ls = "ts",
				denols = "ts",
				basedpyright = "python",
				helm_ls = "yaml",
				gitlab_ci_ls = "yaml",
				oxlint = "ts",
				-- Additional common servers
				pyright = "python",
				tsserver = "typescript",
				gopls = "go",
				clangd = "cpp",
				html = "html",
				cssls = "css",
				jsonls = "json",
				yamlls = "yaml",
				marksman = "markdown",
				texlab = "tex",
				julials = "julia",
				kotlin_language_server = "kotlin",
				r_language_server = "r",
				dartls = "dart",
				elixirls = "elixir",
				erlangls = "erlang",
				fennel_language_server = "fennel",
				nimls = "nim",
				ocamllsp = "ocaml",
				perlnavigator = "perl",
				phpactor = "php",
				powershell_es = "powershell",
				prismals = "prisma",
				puppet = "puppet",
				rnix = "nix",
				ruby_ls = "ruby",
				scalametals = "scala",
				solargraph = "ruby",
				sorbet = "ruby",
				sqlls = "sql",
				tailwindcss = "css",
				terraformls = "terraform",
				vimls = "vim",
				volar = "vue",
				zls = "zig",
			}

			local filetype = server_to_filetype[item.server_name] or "default"
			local devicon = devicons.get_icon("file." .. filetype, filetype, { default = true })

			-- Format with status icon and language icon
			return string.format("%s %s %s", item.status == "running" and "=>" or "--", devicon, item.server_name)
		end,
		kind = "lsp_server",
	}, function(selected)
		if selected and selected.action then
			selected.action()
		end
	end)
end

-- Function to get current buffer LSP info
function M.get_buffer_lsp_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #clients == 0 then
		return "No LSP clients attached"
	end

	local info = {}
	for _, client in ipairs(clients) do
		table.insert(info, string.format("%s (ID: %d)", client.name, client.id))
	end

	return table.concat(info, ", ")
end

-- Function to restart all LSP servers
function M.restart_all_servers()
	-- Snapshot the running servers, stop them, then re-enable the same set.
	local running = vim.tbl_keys(get_lsp_clients())

	for _, server_name in ipairs(running) do
		stop_server(server_name)
	end

	-- Defer so clients finish shutting down before we re-enable them;
	-- vim.lsp.enable re-attaches to matching open buffers.
	vim.schedule(function()
		for _, server_name in ipairs(running) do
			start_server(server_name)
		end
		vim.notify(string.format("Restarted %d LSP servers", #running), vim.log.levels.INFO)
	end)
end

-- Function to show LSP status in statusline
function M.get_statusline_text()
	local clients = get_lsp_clients()
	local count = vim.tbl_count(clients)

	if count == 0 then
		return "LSP: None"
	else
		return string.format("LSP: %d", count)
	end
end

-- Setup function
function M.setup()
	-- Add keybinding to snacks configuration
	local Snacks = require("snacks")

	-- Add LSP manager to snacks keybindings
	vim.keymap.set("n", "<leader>lm", M.open_lsp_picker, { desc = "LSP Manager" })
	vim.keymap.set("n", "<leader>lr", M.restart_all_servers, { desc = "Restart LSP Servers" })

	-- Add to snacks picker if available
	if Snacks and Snacks.picker then
		-- This will be available after snacks is loaded
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- Add LSP manager to snacks picker
				if Snacks.picker then
					-- You can add this to your snacks configuration if desired
					-- vim.notify("LSP Manager loaded. Use <leader>lm to open the picker.", vim.log.levels.INFO)
				end
			end,
		})
	end
end

-- Auto-setup when required
M.setup()

return M
