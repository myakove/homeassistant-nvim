-- Main plugin module
local M = {}
local config = require("homeassistant.config")

-- Plugin state
M._initialized = false
M._api = nil

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
  
  -- Initialize API client
  M._api = require("homeassistant.api").new(config.get())
  
  -- Setup completion sources
  require("homeassistant.completion").setup(M._api)
  
  -- Setup LSP features (if enabled in config)
  local user_cfg = config.get()
  if user_cfg.lsp and user_cfg.lsp.enabled ~= false then
    require("homeassistant.lsp").setup(M._api, user_cfg.lsp)
    require("homeassistant.utils.logger").debug("LSP features enabled")
  end
  
  -- Register commands
  M._register_commands()
  
  M._initialized = true
  require("homeassistant.utils.logger").debug("Home Assistant plugin initialized")
end

-- Register user commands
function M._register_commands()
  vim.api.nvim_create_user_command("HADashboard", function()
    require("homeassistant.ui.dashboard").toggle()
  end, { desc = "Toggle Home Assistant dashboard" })
  
  vim.api.nvim_create_user_command("HAEntityState", function(opts)
    require("homeassistant.ui.state_viewer").show(opts.args)
  end, { nargs = 1, desc = "Show entity state" })
  
  vim.api.nvim_create_user_command("HAServiceCall", function()
    require("homeassistant.actions.service_call").prompt()
  end, { desc = "Call Home Assistant service" })
  
  vim.api.nvim_create_user_command("HAReloadCache", function()
    M._api:refresh_cache()
    vim.notify("Home Assistant cache reloaded", vim.log.levels.INFO)
  end, { desc = "Reload Home Assistant entity cache" })
  
  vim.api.nvim_create_user_command("HAConnect", function()
    if M._api and M._api.client then
      M._api.client:connect(function(err, success)
        if success then
          vim.notify("Connected to Home Assistant", vim.log.levels.INFO)
        else
          vim.notify("Failed to connect: " .. tostring(err), vim.log.levels.ERROR)
        end
      end)
    else
      vim.notify("Home Assistant plugin not initialized", vim.log.levels.ERROR)
    end
  end, { desc = "Connect to Home Assistant WebSocket" })
  
  vim.api.nvim_create_user_command("HAPicker", function()
    require("homeassistant.ui.picker").entities()
  end, { desc = "Pick and control Home Assistant entity" })
  
  vim.api.nvim_create_user_command("HAComplete", function()
    -- Manually trigger completion for debugging
    local has_blink = pcall(require, "blink.cmp")
    if has_blink then
      -- Trigger blink.cmp completion
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-Space>", true, false, true), "n", false)
      vim.notify("Completion triggered (blink.cmp)", vim.log.levels.INFO)
    else
      local has_cmp, cmp = pcall(require, "cmp")
      if has_cmp then
        -- Trigger nvim-cmp completion
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-Space>", true, false, true), "n", false)
        vim.notify("Completion triggered (nvim-cmp)", vim.log.levels.INFO)
      else
        vim.notify("No completion plugin found", vim.log.levels.WARN)
      end
    end
  end, { desc = "Manually trigger Home Assistant completion" })
  
  vim.api.nvim_create_user_command("HADebug", function()
    -- Debug information (wrapped in pcall to prevent crashes)
    local ok, err = pcall(function()
      local info = {
        "=== Home Assistant Plugin Debug ===",
        "Plugin initialized: " .. tostring(M._initialized),
        "API available: " .. tostring(M._api ~= nil),
      }
      
      -- Check completion plugin
      local has_blink = pcall(require, "blink.cmp")
      local has_cmp = pcall(require, "cmp")
      table.insert(info, "Completion: " .. (has_blink and "blink.cmp" or has_cmp and "nvim-cmp" or "none"))
      
      -- Check if connected (safely)
      if M._api and M._api.client then
        local connected = pcall(function() return M._api.client:is_connected() end)
        table.insert(info, "WebSocket connected: " .. tostring(connected))
      else
        table.insert(info, "WebSocket connected: false")
      end
      
      -- Check filetype
      table.insert(info, "Current filetype: " .. vim.bo.filetype)
      
      -- Test entity completion source
      local has_source, source = pcall(require, "homeassistant.completion.blink_entities")
      table.insert(info, "Entity source loaded: " .. tostring(has_source))
      if has_source then
        local ok2, source_inst = pcall(source.new)
        if ok2 then
          local ok3, enabled = pcall(function() return source_inst:enabled() end)
          table.insert(info, "Source enabled: " .. tostring(ok3 and enabled))
        end
      end
      
      vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
    end)
    
    if not ok then
      vim.notify("HADebug error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end, { desc = "Show Home Assistant debug info" })
end

-- Get API client instance
function M.get_api()
  return M._api
end

return M
