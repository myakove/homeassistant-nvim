-- Main plugin module
local M = {}
local config = require("homeassistant.config")

-- Plugin state
M._initialized = false
M._lsp_client = nil
M._user_config = nil -- Store user config for lazy setup

-- Setup function called by users in their config
function M.setup(user_config)
  -- Store user config for potential lazy initialization
  M._user_config = user_config

  -- Merge user config with defaults (but don't initialize yet if paths are configured)
  config.setup(user_config)

  local user_cfg = config.get()

  local paths = user_cfg.paths

  if paths == nil or #paths == 0 then
    -- No path restrictions, initialize immediately
    M._do_setup()
  else
    -- Path restrictions configured - DO NOT initialize automatically
    -- Just store the config. Initialization will happen only when:
    -- 1. User's lazy.nvim init function calls lazy.load() for matching files
    -- 2. Plugin's setup() is called from config function (which happens when plugin loads)
    --    At that point, we rely on the user's init function to only load the plugin
    --    when paths match, so we can initialize here safely
    -- But to be extra safe, check the current buffer path before initializing
    local current_buf = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(current_buf)

    if filepath and filepath ~= "" then
      local current_path = vim.fn.fnamemodify(filepath, ":p")
      local path_matcher = require("homeassistant.utils.path_matcher")
      -- Only initialize if path actually matches
      if path_matcher.matches(current_path, paths) then
        M._do_setup()
      end
      -- If path doesn't match, don't initialize - plugin stays inactive
    end
    -- If no filepath when setup() is called, don't initialize
  end
end

-- Internal function to perform actual initialization
function M._do_setup()
  if M._initialized then
    require("homeassistant.utils.logger").warn("Plugin already initialized")
    return
  end

  local user_cfg = config.get()
  local logger = require("homeassistant.utils.logger")

  -- Initialize logger with config
  logger.init(user_cfg)

  -- Setup LSP client (if enabled)
  if user_cfg.lsp and user_cfg.lsp.enabled ~= false then
    M._lsp_client = require("homeassistant.lsp_client")
    local lsp_ok = M._lsp_client.setup(user_cfg)
    if not lsp_ok then
      logger.warn("Failed to setup LSP client - some features may be unavailable")
    end
  else
    logger.warn("LSP disabled in config - plugin features will be limited")
  end

  -- Register commands
  M._register_commands()

  -- Setup keymaps (if enabled)
  M._setup_keymaps()

  M._initialized = true
end

-- Lazy setup function called by autocommands when path matches
-- Returns true if initialization happened, false otherwise
-- @param buf: Optional buffer number to check (defaults to current buffer)
function M._lazy_setup(buf)
  -- Skip if already initialized
  if M._initialized then
    return true
  end

  -- Check if user has called setup() yet
  if not M._user_config then
    -- User hasn't called setup() yet, nothing to do
    return false
  end

  -- Check if buffer path matches configured patterns
  local path_matcher = require("homeassistant.utils.path_matcher")
  local buf_to_check = buf or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(buf_to_check)

  if filepath == "" or not filepath then
    -- No file path, skip - don't initialize for buffers without files
    return false
  end

  local current_path = vim.fn.fnamemodify(filepath, ":p")

  local user_cfg = config.get()
  local paths = user_cfg.paths

  if paths == nil or #paths == 0 then
    -- No paths configured (or empty), initialize
    M._do_setup()
    return true
  end

  -- Check if path matches
  local matches = path_matcher.matches(current_path, paths)

  if not matches then
    -- Path doesn't match, skip initialization
    return false
  end

  -- Path matches, initialize now
  M._do_setup()
  return true
end

-- Register user commands
function M._register_commands()
  vim.api.nvim_create_user_command("HADashboard", function()
    if not M._initialized then
      vim.notify(
        "Home Assistant plugin not initialized. Check path configuration.",
        vim.log.levels.WARN
      )
      return
    end
    require("homeassistant.ui.dashboard").toggle()
  end, { desc = "Toggle Home Assistant dashboard" })

  vim.api.nvim_create_user_command("HAEntityState", function(opts)
    require("homeassistant.ui.state_viewer").show(opts.args)
  end, { nargs = 1, desc = "Show entity state" })

  vim.api.nvim_create_user_command("HAReloadCache", function()
    if M._lsp_client and M._lsp_client.is_connected() then
      local client = M._lsp_client.get_client()
      if client then
        client.request('workspace/executeCommand', {
          command = "homeassistant.reloadCache",
          arguments = {},
        }, function(err, result)
          if err then
            local err_msg = type(err) == "table" and err.message or tostring(err)
            vim.notify("Failed to reload cache: " .. err_msg, vim.log.levels.ERROR)
          else
            vim.notify("Reloading Home Assistant cache...", vim.log.levels.INFO)
          end
        end)
      end
    else
      vim.notify("LSP not connected", vim.log.levels.ERROR)
    end
  end, { desc = "Reload Home Assistant entity cache" })

  vim.api.nvim_create_user_command("HAPicker", function()
    require("homeassistant.ui.picker").entities()
  end, { desc = "Pick and control Home Assistant entity" })

  vim.api.nvim_create_user_command("HAEditDashboard", function()
    require("homeassistant.ui.dashboard_editor").pick_dashboard()
  end, { desc = "Edit Home Assistant Lovelace dashboard" })

  vim.api.nvim_create_user_command("HAComplete", function()
    -- Check if we're in Insert mode
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= "i" then
      vim.notify("HAComplete must be used in Insert mode", vim.log.levels.WARN)
      return
    end
    -- Trigger LSP completion
    vim.lsp.completion.trigger()
  end, { desc = "Manually trigger Home Assistant completion (Insert mode only)" })

  vim.api.nvim_create_user_command("HADebug", function()
    -- Debug information (wrapped in pcall to prevent crashes)
    local ok, err = pcall(function()
      local info = {
        "=== Home Assistant Plugin Debug ===",
        "Plugin initialized: " .. tostring(M._initialized),
        "LSP client: " .. tostring(M._lsp_client ~= nil),
      }

      -- Check LSP connection
      if M._lsp_client then
        local lsp_connected = M._lsp_client.is_connected()
        table.insert(info, "LSP connected: " .. tostring(lsp_connected))
      end

      -- Check filetype
      table.insert(info, "Current filetype: " .. vim.bo.filetype)

      vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
    end)

    if not ok then
      vim.notify("HADebug error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end, { desc = "Show Home Assistant debug info" })
end

-- Setup keymaps
function M._setup_keymaps()
  local user_cfg = config.get()

  -- Check if keymaps are enabled
  if not user_cfg.keymaps or user_cfg.keymaps.enabled == false then
    return
  end

  local maps = user_cfg.keymaps

  -- Dashboard keymap
  if maps.dashboard then
    vim.keymap.set("n", maps.dashboard, "<cmd>HADashboard<cr>",
      { desc = "HA Dashboard", silent = true })
  end

  -- Picker keymap (only if telescope available)
  if maps.picker then
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
      vim.keymap.set("n", maps.picker, "<cmd>HAPicker<cr>",
        { desc = "HA Entity Picker", silent = true })
    end
  end

  -- Reload cache keymap
  if maps.reload_cache then
    vim.keymap.set("n", maps.reload_cache, "<cmd>HAReloadCache<cr>",
      { desc = "HA Reload Cache", silent = true })
  end

  -- Debug keymap
  if maps.debug then
    vim.keymap.set("n", maps.debug, "<cmd>HADebug<cr>",
      { desc = "HA Debug Info", silent = true })
  end

  -- Edit dashboard keymap
  if maps.edit_dashboard then
    vim.keymap.set("n", maps.edit_dashboard, "<cmd>HAEditDashboard<cr>",
      { desc = "HA Edit Dashboard", silent = true })
  end
end

-- Get LSP client instance
function M.get_lsp_client()
  return M._lsp_client
end

return M
