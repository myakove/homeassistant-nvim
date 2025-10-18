-- Main plugin module
local M = {}
local config = require("homeassistant.config")

-- Plugin state
M._initialized = false
M._lsp_client = nil

-- Setup function called by users in their config
function M.setup(user_config)
  if M._initialized then
    require("homeassistant.utils.logger").warn("Plugin already initialized")
    return
  end
  
  -- Merge user config with defaults
  config.setup(user_config)
  
  -- Initialize logger with config
  require("homeassistant.utils.logger").init(config.get())
  
  local user_cfg = config.get()
  local logger = require("homeassistant.utils.logger")
  
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

-- Register user commands
function M._register_commands()
  vim.api.nvim_create_user_command("HADashboard", function()
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
            vim.notify("Failed to reload cache: " .. err.message, vim.log.levels.ERROR)
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
    vim.lsp.buf.completion()
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
